using System;
using Vortice.D3DCompiler;
using Vortice.Direct3D;
using Vortice.Direct3D11;
using Vortice.DXGI;

namespace IndigoWindows;

/// <summary>
/// GPU-based texture scaling using a fullscreen triangle blit with bilinear filtering.
/// </summary>
public class TextureScaler : IDisposable
{
    private readonly ID3D11Device _device;
    private readonly ID3D11DeviceContext _context;
    private readonly ID3D11VertexShader _vertexShader;
    private readonly ID3D11PixelShader _pixelShader;
    private readonly ID3D11SamplerState _sampler;
    private ID3D11Texture2D? _outputTexture;
    private ID3D11RenderTargetView? _rtv;
    private int _outputW, _outputH;
    private bool _disposed;

    private const string ShaderSource = @"
Texture2D tex : register(t0);
SamplerState samp : register(s0);

struct VS_OUT {
    float4 pos : SV_Position;
    float2 uv  : TEXCOORD0;
};

VS_OUT VS(uint id : SV_VertexID) {
    VS_OUT o;
    o.uv = float2((id << 1) & 2, id & 2);
    o.pos = float4(o.uv * float2(2, -2) + float2(-1, 1), 0, 1);
    return o;
}

float4 PS(VS_OUT i) : SV_Target {
    return tex.Sample(samp, i.uv);
}
";

    public TextureScaler(ID3D11Device device, ID3D11DeviceContext context)
    {
        _device = device;
        _context = context;

        var vsBytecode = Compiler.Compile(ShaderSource, "VS", null, "vs_4_0");
        var psBytecode = Compiler.Compile(ShaderSource, "PS", null, "ps_4_0");

        _vertexShader = _device.CreateVertexShader(vsBytecode.Span);
        _pixelShader = _device.CreatePixelShader(psBytecode.Span);

        _sampler = _device.CreateSamplerState(new SamplerDescription
        {
            Filter = Filter.MinMagMipLinear,
            AddressU = TextureAddressMode.Clamp,
            AddressV = TextureAddressMode.Clamp,
            AddressW = TextureAddressMode.Clamp,
        });
    }

    /// <summary>
    /// Ensure the output texture exists at the desired size.
    /// </summary>
    public void EnsureOutputTexture(int width, int height)
    {
        if (_outputTexture != null && _outputW == width && _outputH == height)
            return;

        _rtv?.Dispose();
        _outputTexture?.Dispose();

        _outputW = width;
        _outputH = height;

        _outputTexture = _device.CreateTexture2D(new Texture2DDescription
        {
            Width = (uint)width,
            Height = (uint)height,
            MipLevels = 1,
            ArraySize = 1,
            Format = Format.B8G8R8A8_UNorm,
            SampleDescription = new SampleDescription(1, 0),
            Usage = ResourceUsage.Default,
            BindFlags = BindFlags.ShaderResource | BindFlags.RenderTarget,
        });

        _rtv = _device.CreateRenderTargetView(_outputTexture);
    }

    /// <summary>
    /// Scale sourceTexture to the configured output size. Returns the output texture.
    /// </summary>
    public ID3D11Texture2D Scale(ID3D11Texture2D sourceTexture)
    {
        if (_outputTexture == null || _rtv == null)
            throw new InvalidOperationException("Call EnsureOutputTexture first.");

        using var srv = _device.CreateShaderResourceView(sourceTexture, new ShaderResourceViewDescription
        {
            Format = Format.B8G8R8A8_UNorm,
            ViewDimension = ShaderResourceViewDimension.Texture2D,
            Texture2D = new Texture2DShaderResourceView { MipLevels = 1, MostDetailedMip = 0 }
        });

        _context.VSSetShader(_vertexShader);
        _context.PSSetShader(_pixelShader);
        _context.PSSetShaderResource(0, srv);
        _context.PSSetSampler(0, _sampler);
        _context.OMSetRenderTargets(_rtv);
        _context.RSSetViewport(0, 0, _outputW, _outputH);
        _context.IASetPrimitiveTopology(PrimitiveTopology.TriangleList);
        _context.IASetInputLayout(null);

        _context.Draw(3, 0);

        // Unbind
        _context.PSSetShaderResource(0, null);
        _context.OMSetRenderTargets((ID3D11RenderTargetView?)null);

        return _outputTexture;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _rtv?.Dispose();
        _outputTexture?.Dispose();
        _vertexShader?.Dispose();
        _pixelShader?.Dispose();
        _sampler?.Dispose();
    }
}
