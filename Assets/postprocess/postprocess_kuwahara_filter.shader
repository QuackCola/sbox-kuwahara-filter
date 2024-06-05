HEADER
{
	Description = "Kuwahara Filter Post Processing Shader";
	DevShader = true;
}

MODES
{
    Default();
    VrForward();
}

FEATURES
{
    #include "common/features.hlsl"
}

COMMON
{
	#include "common/shared.hlsl"

}

struct VertexInput
{
    float3 vPositionOs : POSITION < Semantic( PosXyz ); >;
    float2 vTexCoord : TEXCOORD0 < Semantic( LowPrecisionUv ); >;
};

struct PixelInput
{
    float2 vTexCoord : TEXCOORD0;

	// VS only
	#if ( PROGRAM == VFX_PROGRAM_VS )
		float4 vPositionPs		: SV_Position;
	#endif

	// PS only
	#if ( ( PROGRAM == VFX_PROGRAM_PS ) )
		float4 vPositionSs		: SV_Position;
	#endif
};

VS
{
    PixelInput MainVs( VertexInput i )
    {
        PixelInput o;
        o.vPositionPs = float4(i.vPositionOs.xyz, 1.0f);
        o.vTexCoord = i.vTexCoord;
        return o;
    }
}

PS
{
    #include "postprocess/common.hlsl"
    #include "postprocess/functions.hlsl"

    bool g_bDirectional < Attribute("Kuwahara.Directional"); Default(0); >;
    float g_flRadiusX < Attribute("Kuwahara.RadiusX"); Range(0,16); Default(3); >;
    float g_flRadiusY < Attribute("Kuwahara.RadiusY"); Range(0,16); Default(5); >;

    CreateTexture2D( g_tColorBuffer ) < Attribute( "ColorBuffer" ); SrgbRead( true ); Filter( MIN_MAG_LINEAR_MIP_POINT ); AddressU( MIRROR ); AddressV( MIRROR ); >;

    float4 FetchSceneColor( float2 vScreenUv )
    {
        return Tex2D( g_tColorBuffer, vScreenUv.xy );
    }

    float GetRelativeLuminance(float3 vColor)
    {   
        // https://en.wikipedia.org/wiki/Relative_luminance
        /*
        float3 L = vColor * float3(0.2126,0.7152,0.0722);
        return (L.x + L.y) + L.z;
        */

        return dot(float3(0.2126,0.7152,0.0722),vColor);
    }

    //
    // calculate which ever color region has the lowest standard deviaion.
    //
    float3 CalculateLowestStandardDeviation(float n, float3 vColor, float3 aMean[4], float3 aSigma[4])
    {
        float flMin = 1;
        float flSigma_f;

        [unroll]
        for(int i = 0; i < 4; i++)
        {
            aMean[i] /= n;
            aSigma[i] = abs(aSigma[i] / n - aMean[i] * aMean[i]);

            // find the deviation of each channel and add them together.
            flSigma_f = aSigma[i].r + aSigma[i].g + aSigma[i].b;

            if(flSigma_f < flMin )
            {
                flMin = flSigma_f;
                vColor = aMean[i];
            }
        }

        return vColor;
    }

    
    float3 KuwaharaFilter(float2 flRadius, float2 vScreenUV, float2 vViewSize, bool bDirectional = false)
    {
        float3 aMean[4] = {
            {0,0,0},
            {0,0,0},
            {0,0,0},
            {0,0,0}
        };

        float3 aSigma[4] = {
            {0,0,0},
            {0,0,0},
            {0,0,0},
            {0,0,0}
        };

        float2 aOffsets[4] = {
            {-flRadius.x,-flRadius.y},
            {-flRadius.x,0},
            {0,-flRadius.y},
            {0,0}
        };

        float2 vSamplePosition;
        float2 vTexelSize = 1.0/vViewSize;
        float3 vColor;

        if (bDirectional)
        {
            // Sobel Operator Start 
            float flGradientX = 0;
            float flGradientY = 0;
            int nIndex = 0;

            float aSobelX[9] = { -1 , -2, -1, 0, 0, 0, 1, 2, 1};
            float aSobelY[9] = { -1 , 0, 1, -2, 0, 2, -1, 0, 1};

            [unroll]
            for(int x = -1; x <= 1; x++)
            {
                for(int y = -1; y <= 1; y++)
                {   
                    // Skip unessesary texture lookup.
                    if(nIndex == 4)
                    {
                        nIndex++;
                        continue;
                    }

                    float2 vOffset = float2(x,y) * vTexelSize;
                    float3 vPixelColor = FetchSceneColor(vScreenUV + vOffset).xyz;
                    float vPixelLuminance = GetRelativeLuminance(vPixelColor); // Get the releative luminace of the surrounding pixels of the current pixel that is being sampled.

                    flGradientX += vPixelLuminance * aSobelX[nIndex];
                    flGradientY += vPixelLuminance * aSobelY[nIndex];

                    nIndex++;
                }
            }
            // Sobel Operator End

            float flAngle = 0;

            // Avoid a potential divide by zero in flGradientX
            if(abs(flGradientX) > 0.001)
            {
                flAngle = atan(flGradientY / flGradientX);
            }

            // Calculate sine & cosine from flAngle
            float flSine = sin(flAngle);
            float flCosine = cos(flAngle);

            // Loop through for our samples. Note : Have to include a fucking duplcate of the loop below in here since it wont work outside the if (bDirectional) statement..
            [unroll]
            for(int i = 0; i < 4; i++) 
            {
                for(int j = 0; j <= flRadius.x; j++)
                {
                    for(int k = 0; k <= flRadius.y; k++)
                    {
                        vSamplePosition = float2(j,k) + aOffsets[i];

                        float2 vOffs = vSamplePosition * vTexelSize;
                        vOffs = float2(vOffs.x * flCosine - vOffs.y * flSine, vOffs.x * flSine + vOffs.y * flCosine);// Rotate our samples.
                        float2 vUVpos = vScreenUV + vOffs; // Divide vSamplePosition by vOffs to get back into the 0 to 1 range.

                        vColor = FetchSceneColor(vUVpos).xyz;
                        aMean[i] += vColor; // Calculate the average of multiple samples.
                        aSigma[i] += vColor * vColor; // Standard deviation.
                    }
                }
            }
        } 
        else 
        {
            // Loop through for our samples.
            [unroll]
            for(int i = 0; i < 4; i++) 
            {
                for(int j = 0; j <= flRadius.x; j++)
                {
                    for(int k = 0; k <= flRadius.y; k++)
                    {
                        vSamplePosition = float2(j,k) + aOffsets[i];

                        float2 vOffs = vSamplePosition * vTexelSize;
                        float2 vUVpos = vScreenUV + vOffs; // Divide vSamplePosition by vOffs to get back into the 0 to 1 range?.

                        vColor = FetchSceneColor(vUVpos).xyz;
                        aMean[i] += vColor; // Calculate the average of multiple samples.
                        aSigma[i] += vColor * vColor; // Standard deviation
                    }
                }
            }
        }

        float n = (flRadius.x + 1) * (flRadius.y + 1); // number of samples that we have taken per region
        return CalculateLowestStandardDeviation(n,vColor,aMean,aSigma);
    }

    //
    // Main
    //
    float4 MainPs( PixelInput i ): SV_Target
    {
        float2 vScreenUv = i.vPositionSs.xy / g_vRenderTargetSize;
        //float4 vSceneColor = FetchSceneColor( vScreenUv );

        //g_vRenderTargetSize seems to be what is used in place of stuff like TexelSize from unity & Unreal I guess?.

        return float4(KuwaharaFilter(round(float2(g_flRadiusX,g_flRadiusY)),vScreenUv,g_vRenderTargetSize,g_bDirectional),1);
    }
}