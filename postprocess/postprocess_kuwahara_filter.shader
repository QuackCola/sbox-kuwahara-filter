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
	float2 uv : TEXCOORD0;

	// VS only
	#if ( PROGRAM == VFX_PROGRAM_VS )
		float4 vPositionPs		: SV_Position;
	#endif

	// PS only
	#if ( ( PROGRAM == VFX_PROGRAM_PS ) )
		float4 vPositionSs		: SV_ScreenPosition;
	#endif
};

VS
{
    PixelInput MainVs( VertexInput i )
    {
        PixelInput o;
        
        o.vPositionPs = float4(i.vPositionOs.xy, 0.0f, 1.0f);
        o.uv = i.vTexCoord;
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

    CreateTexture2D( g_tColorBuffer ) < Attribute( "ColorBuffer" );  	SrgbRead( true ); Filter( MIN_MAG_LINEAR_MIP_POINT ); AddressU( MIRROR ); AddressV( MIRROR ); >;

    float4 FetchSceneColor( float2 vScreenUv )
    {
        return Tex2D( g_tColorBuffer, vScreenUv.xy );
    }

    float GetRelativeLuminance(float3 vSceneColor)
    {   
        // https://en.wikipedia.org/wiki/Relative_luminance
        /*
        float3 L = vSceneColor * float3(0.2126,0.7152,0.0722);
        return (L.x + L.y) + L.z;
        */

        return dot(float3(0.2126,0.7152,0.0722),vSceneColor);
    }

    //
    // calculate which ever color region has the lowest standard deviaion.
    //
    float3 GetLowestStandardDeviation(float n, float3 vColor, float3 aMean[4], float3 aSigma[4])
    {
        float flMin = 1;
        float sigma_f;

        [unroll]
        for(int i = 0; i < 4; i++)
        {
            aMean[i] /= n;
            aSigma[i] = abs(aSigma[i] / n - aMean[i] * aMean[i]);

            // find the deviation of each channel and add them together.
            sigma_f = aSigma[i].r + aSigma[i].g + aSigma[i].b;

            if(sigma_f < flMin )
            {
                flMin = sigma_f;
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
            float GradientX = 0;
            float GradientY = 0;
            int index = 0;

            float sobelX[9] = { -1 , -2, -1, 0, 0, 0, 1, 2, 1};
            float sobelY[9] = { -1 , 0, 1, -2, 0, 2, -1, 0, 1};

            [unroll]
            for(int x = -1; x <= 1; x++)
            {
                for(int y = -1; y <= 1; y++)
                {   
                    // Skip unessesary texture lookup.
                    if(index == 4)
                    {
                        index++;
                        continue;
                    }

                    float2 vOffset = float2(x,y) * vTexelSize;
                    float3 vPixelColor = FetchSceneColor(vScreenUV + vOffset).xyz;
                    float vPixelLuminance = GetRelativeLuminance(vPixelColor); // Get the releative luminace of the surrounding pixels of the current pixel that is being sampled.

                    GradientX += vPixelLuminance * sobelX[index];
                    GradientY += vPixelLuminance * sobelY[index];

                    index++;
                }
            }
            // Sobel Operator End

            float vAngle = 0;

            // Avoid a potential divide by zero.
            if(abs(GradientX) > 0.001)
            {
                vAngle = atan(GradientY / GradientX);
            }

            // Calculate sin & cos fron vAngle
            float s = sin(vAngle);
            float c = cos(vAngle);

            // Loop through for our samples. Have to include a duplcate of the loop below in here, but fuck it atleast it works.
            [unroll]
            for(int i = 0; i < 4; i++) 
            {
                for(int j = 0; j <= flRadius.x; j++)
                {
                    for(int k = 0; k <= flRadius.y; k++)
                    {
                        vSamplePosition = float2(j,k) + aOffsets[i];

                        float2 offs = vSamplePosition * vTexelSize;
                        offs = float2(offs.x * c - offs.y * s, offs.x * s + offs.y * c);// Rotate our samples.
                        float2 vUVpos = vScreenUV + offs; // Divide vSamplePosition by offs to get back into the 0 to 1 range.

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

                        float2 offs = vSamplePosition * vTexelSize;
                        float2 vUVpos = vScreenUV + offs; // Divide vSamplePosition by offs to get back into the 0 to 1 range?.

                        vColor = FetchSceneColor(vUVpos).xyz;
                        aMean[i] += vColor; // Calculate the average of multiple samples.
                        aSigma[i] += vColor * vColor; // Standard deviation
                    }
                }
            }
        }

        float n = (flRadius.x + 1) * (flRadius.y + 1); // number of samples that we have taken per region
        return GetLowestStandardDeviation(n,vColor,aMean,aSigma);
    }

    //
    // Main
    //
    float4 MainPs( PixelInput i ): SV_Target
    {
        float2 vScreenUv = i.vPositionSs.xy / g_vRenderTargetSize;
        float4 SceneColor = FetchSceneColor( vScreenUv );

        //g_vRenderTargetSize seems to be what is used in place of stuff like TexelSize from unity & Unreal I guess?.

        return float4(KuwaharaFilter(round(float2(g_flRadiusX,g_flRadiusY)),vScreenUv,g_vRenderTargetSize,g_bDirectional),1);
    }
}