        ��  ��                  �6      ��
 ��'    0	        #ifdef SHADER_MODEL // make safe to include in resource file to enforce dependency
#define FMT_32 0
#define FMT_24 1
#define FMT_16 2
#define FMT_PAL 4 /* flag bit */

// And I say this as an ATI user.
#define ATI_SUCKS 1

#if SHADER_MODEL >= 0x400

#ifndef VS_BPPZ
#define VS_BPPZ 0
#define VS_TME 1
#define VS_FST 1
#endif

#ifndef GS_IIP
#define GS_IIP 0
#define GS_PRIM 3
#endif

#ifndef PS_FST
#define PS_FST 0
#define PS_WMS 0
#define PS_WMT 0
#define PS_FMT FMT_32
#define PS_AEM 0
#define PS_TFX 0
#define PS_TCC 1
#define PS_ATST 1
#define PS_FOG 0
#define PS_CLR1 0
#define PS_FBA 0
#define PS_AOUT 0
#define PS_LTF 1
#define PS_COLCLIP 0
#define PS_DATE 0
#define PS_SPRITEHACK 0
#define PS_TCOFFSETHACK 0
#define PS_POINT_SAMPLER 0
#endif

struct VS_INPUT
{
	float2 st : TEXCOORD0;
	float4 c : COLOR0;
	float q : TEXCOORD1;
	uint2 p : POSITION0;
	uint z : POSITION1;
	uint2 uv : TEXCOORD2;
	float4 f : COLOR1;
};

struct VS_OUTPUT
{
	float4 p : SV_Position;
	float4 t : TEXCOORD0;
#if VS_RTCOPY
	float4 tp : TEXCOORD1;
#endif
	float4 c : COLOR0;
};

struct PS_INPUT
{
	float4 p : SV_Position;
	float4 t : TEXCOORD0;
#if PS_DATE > 0
	float4 tp : TEXCOORD1;
#endif
	float4 c : COLOR0;
};

struct PS_OUTPUT
{
	float4 c0 : SV_Target0;
	float4 c1 : SV_Target1;
};

Texture2D<float4> Texture : register(t0);
Texture2D<float4> Palette : register(t1);
Texture2D<float4> RTCopy : register(t2);
SamplerState TextureSampler : register(s0);
SamplerState PaletteSampler : register(s1);
SamplerState RTCopySampler : register(s2);

cbuffer cb0
{
	float4 VertexScale;
	float4 VertexOffset;
	float2 TextureScale;
};

cbuffer cb1
{
	float3 FogColor;
	float AREF;
	float4 HalfTexel;
	float4 WH;
	float4 MinMax;
	float2 MinF;
	float2 TA;
	uint4 MskFix;
	float4 TC_OffsetHack;
};

float4 sample_c(float2 uv)
{
	if (ATI_SUCKS && PS_POINT_SAMPLER)
	{
		// Weird issue with ATI cards (happens on at least HD 4xxx and 5xxx),
		// it looks like they add 127/128 of a texel to sampling coordinates
		// occasionally causing point sampling to erroneously round up.
		// I'm manually adjusting coordinates to the centre of texels here,
		// though the centre is just paranoia, the top left corner works fine.
		uv = (trunc(uv * WH.zw) + float2(0.5, 0.5)) / WH.zw;
	}
	return Texture.Sample(TextureSampler, uv);
}

float4 sample_p(float u)
{
	return Palette.Sample(PaletteSampler, u);
}

float4 sample_rt(float2 uv)
{
	return RTCopy.Sample(RTCopySampler, uv);
}

#elif SHADER_MODEL <= 0x300

#ifndef VS_BPPZ
#define VS_BPPZ 0
#define VS_TME 1
#define VS_FST 1
#define VS_LOGZ 1
#endif

#ifndef PS_FST
#define PS_FST 0
#define PS_WMS 0
#define PS_WMT 0
#define PS_FMT FMT_32
#define PS_AEM 0
#define PS_TFX 0
#define PS_TCC 0
#define PS_ATST 4
#define PS_FOG 0
#define PS_CLR1 0
#define PS_RT 0
#define PS_LTF 0
#define PS_COLCLIP 0
#define PS_DATE 0
#endif

struct VS_INPUT
{
	float4 p : POSITION0; 
	float2 t : TEXCOORD0;
	float4 c : COLOR0;
	float4 f : COLOR1;
};

struct VS_OUTPUT
{
	float4 p : POSITION;
	float4 t : TEXCOORD0;
#if VS_RTCOPY
	float4 tp : TEXCOORD1;
#endif
	float4 c : COLOR0;
};

struct PS_INPUT
{
	float4 t : TEXCOORD0;
#if PS_DATE > 0
	float4 tp : TEXCOORD1;
#endif
	float4 c : COLOR0;
};

sampler Texture : register(s0);
sampler Palette : register(s1);
sampler RTCopy : register(s2);
sampler1D UMSKFIX : register(s3);
sampler1D VMSKFIX : register(s4);

float4 vs_params[3];

#define VertexScale vs_params[0]
#define VertexOffset vs_params[1]
#define TextureScale vs_params[2].xy

float4 ps_params[7];

#define FogColor	ps_params[0].bgr
#define AREF		ps_params[0].a
#define HalfTexel	ps_params[1]
#define WH			ps_params[2]
#define MinMax		ps_params[3]
#define MinF		ps_params[4].xy
#define TA			ps_params[4].zw

#define TC_OffsetHack ps_params[6]

float4 sample_c(float2 uv)
{
	return tex2D(Texture, uv);
}

float4 sample_p(float u)
{
	return tex2D(Palette, u);
}

float4 sample_rt(float2 uv)
{
	return tex2D(RTCopy, uv);
}

#endif

float4 wrapuv(float4 uv)
{
	if(PS_WMS == PS_WMT)
	{
/*
		if(PS_WMS == 0)
		{
			uv = frac(uv);
		}
		else if(PS_WMS == 1)
		{
			uv = saturate(uv);
		}
		else
*/ 
		if(PS_WMS == 2)
		{
			uv = clamp(uv, MinMax.xyxy, MinMax.zwzw);
		}
		else if(PS_WMS == 3)
		{
			#if SHADER_MODEL >= 0x400
			uv = (float4)(((int4)(uv * WH.xyxy) & MskFix.xyxy) | MskFix.zwzw) / WH.xyxy;
			#elif SHADER_MODEL <= 0x300
			uv.x = tex1D(UMSKFIX, uv.x);
			uv.y = tex1D(VMSKFIX, uv.y);
			uv.z = tex1D(UMSKFIX, uv.z);
			uv.w = tex1D(VMSKFIX, uv.w);
			#endif
		}
	}
	else
	{
/*	
		if(PS_WMS == 0)
		{
			uv.xz = frac(uv.xz);
		}
		else if(PS_WMS == 1)
		{
			uv.xz = saturate(uv.xz);
		}
		else 
*/		
		if(PS_WMS == 2)
		{
			uv.xz = clamp(uv.xz, MinMax.xx, MinMax.zz);
		}
		else if(PS_WMS == 3)
		{
			#if SHADER_MODEL >= 0x400
			uv.xz = (float2)(((int2)(uv.xz * WH.xx) & MskFix.xx) | MskFix.zz) / WH.xx;
			#elif SHADER_MODEL <= 0x300
			uv.x = tex1D(UMSKFIX, uv.x);
			uv.z = tex1D(UMSKFIX, uv.z);
			#endif
		}
/*
		if(PS_WMT == 0)
		{
			uv.yw = frac(uv.yw);
		}
		else if(PS_WMT == 1)
		{
			uv.yw = saturate(uv.yw);
		}
		else 
*/
		if(PS_WMT == 2)
		{
			uv.yw = clamp(uv.yw, MinMax.yy, MinMax.ww);
		}
		else if(PS_WMT == 3)
		{
			#if SHADER_MODEL >= 0x400
			uv.yw = (float2)(((int2)(uv.yw * WH.yy) & MskFix.yy) | MskFix.ww) / WH.yy;
			#elif SHADER_MODEL <= 0x300
			uv.y = tex1D(VMSKFIX, uv.y);
			uv.w = tex1D(VMSKFIX, uv.w);
			#endif
		}
	}
	
	return uv;
}

float2 clampuv(float2 uv)
{
	if(PS_WMS == 2 && PS_WMT == 2) 
	{
		uv = clamp(uv, MinF, MinMax.zw);
	}
	else if(PS_WMS == 2)
	{
		uv.x = clamp(uv.x, MinF.x, MinMax.z);
	}
	else if(PS_WMT == 2)
	{
		uv.y = clamp(uv.y, MinF.y, MinMax.w);
	}
	
	return uv;
}

float4x4 sample_4c(float4 uv)
{
	float4x4 c;
	
	c[0] = sample_c(uv.xy);
	c[1] = sample_c(uv.zy);
	c[2] = sample_c(uv.xw);
	c[3] = sample_c(uv.zw);

	return c;
}

float4 sample_4a(float4 uv)
{
	float4 c;

	c.x = sample_c(uv.xy).a;
	c.y = sample_c(uv.zy).a;
	c.z = sample_c(uv.xw).a;
	c.w = sample_c(uv.zw).a;
	
	#if SHADER_MODEL <= 0x300
	if(PS_RT) c *= 128.0f / 255;
	#endif

	return c * 255./256 + 0.5/256;
}

float4x4 sample_4p(float4 u)
{
	float4x4 c;
	
	c[0] = sample_p(u.x);
	c[1] = sample_p(u.y);
	c[2] = sample_p(u.z);
	c[3] = sample_p(u.w);

	return c;
}

float4 sample(float2 st, float q)
{
	if(!PS_FST) st /= q;

	#if PS_TCOFFSETHACK
	st += TC_OffsetHack.xy;
	#endif 

	float4 t;
	float4x4 c;
	float2 dd;

/*	
	if(!PS_LTF && PS_FMT <= FMT_16 && PS_WMS < 2 && PS_WMT < 2)
	{
		c[0] = sample_c(st);
	}
*/
	if (!PS_LTF && PS_FMT <= FMT_16 && PS_WMS < 3 && PS_WMT < 3)
	{
		c[0] = sample_c(clampuv(st));
	}
	else
	{
		float4 uv;

		if(PS_LTF)
		{
			uv = st.xyxy + HalfTexel;
			dd = frac(uv.xy * WH.zw);
		}
		else
		{
			uv = st.xyxy;
		}

		uv = wrapuv(uv);

		if(PS_FMT & FMT_PAL)
		{
			c = sample_4p(sample_4a(uv));
		}
		else
		{
			c = sample_4c(uv);
		}
	}

	[unroll]
	for (uint i = 0; i < 4; i++)
	{
		if((PS_FMT & ~FMT_PAL) == FMT_32)
		{
			#if SHADER_MODEL <= 0x300
			if(PS_RT) c[i].a *= 128.0f / 255;
			#endif
		}
		else if((PS_FMT & ~FMT_PAL) == FMT_24)
		{
			c[i].a = !PS_AEM || any(c[i].rgb) ? TA.x : 0;
		}
		else if((PS_FMT & ~FMT_PAL) == FMT_16)
		{
			c[i].a = c[i].a >= 0.5 ? TA.y : !PS_AEM || any(c[i].rgb) ? TA.x : 0; 
		}
	}

	if(PS_LTF)
	{	
		t = lerp(lerp(c[0], c[1], dd.x), lerp(c[2], c[3], dd.x), dd.y);
	}
	else
	{
		t = c[0];
	}

	return t;
}

float4 tfx(float4 t, float4 c)
{
	if(PS_TFX == 0)
	{
		if(PS_TCC) 
		{
			c = c * t * 255.0f / 128;
		}
		else
		{
			c.rgb = c.rgb * t.rgb * 255.0f / 128;
		}
	}
	else if(PS_TFX == 1)
	{
		if(PS_TCC) 
		{
			c = t;
		}
		else
		{
			c.rgb = t.rgb;
		}
	}
	else if(PS_TFX == 2)
	{
		c.rgb = c.rgb * t.rgb * 255.0f / 128 + c.a;

		if(PS_TCC) 
		{
			c.a += t.a;
		}
	}
	else if(PS_TFX == 3)
	{
		c.rgb = c.rgb * t.rgb * 255.0f / 128 + c.a;

		if(PS_TCC) 
		{
			c.a = t.a;
		}
	}
	
	return saturate(c);
}

void datst(PS_INPUT input)
{
#if PS_DATE > 0
	float alpha = sample_rt(input.tp.xy).a;
#if SHADER_MODEL >= 0x400
	float alpha0x80 = 128. / 255;
#else
	float alpha0x80 = 1;
#endif

	if (PS_DATE == 1 && alpha >= alpha0x80)
		discard;
	else if (PS_DATE == 2 && alpha < alpha0x80)
		discard;
#endif
}

void atst(float4 c)
{
	float a = trunc(c.a * 255 + 0.01);
	
	if(PS_ATST == 0) // never
	{
		discard;
	}
	else if(PS_ATST == 1) // always
	{
		// nothing to do
	}
	else if(PS_ATST == 2) // l
	{
		#if PS_SPRITEHACK == 0
		clip(AREF - a - 0.5f);
		#endif				
	}
	else if(PS_ATST == 3) // le
	{
		clip(AREF - a + 0.5f);
	}
	else if(PS_ATST == 4) // e
	{
		clip(0.5f - abs(a - AREF));
	}
	else if(PS_ATST == 5) // ge
	{
		clip(a - AREF + 0.5f);
	}
	else if(PS_ATST == 6) // g
	{
		clip(a - AREF - 0.5f);
	}
	else if(PS_ATST == 7) // ne
	{
		clip(abs(a - AREF) - 0.5f);
	}
}

float4 fog(float4 c, float f)
{
	if(PS_FOG)
	{
		c.rgb = lerp(FogColor, c.rgb, f);
	}

	return c;
}

float4 ps_color(PS_INPUT input)
{
	datst(input);

	float4 t = sample(input.t.xy, input.t.w);

	float4 c = tfx(t, input.c);

	atst(c);

	c = fog(c, input.t.z);

	if (PS_COLCLIP == 2)
	{
		c.rgb = 256./255. - c.rgb;
	}
	if (PS_COLCLIP > 0)
	{
		c.rgb *= c.rgb < 128./255;
	}

	if(PS_CLR1) // needed for Cd * (As/Ad/F + 1) blending modes
	{
		c.rgb = 1; 
	}

	return c;
}

#if SHADER_MODEL >= 0x400

VS_OUTPUT vs_main(VS_INPUT input)
{
	if(VS_BPPZ == 1) // 24
	{
		input.z = input.z & 0xffffff; 
	}
	else if(VS_BPPZ == 2) // 16
	{
		input.z = input.z & 0xffff;
	}

	VS_OUTPUT output;
	
	// pos -= 0.05 (1/320 pixel) helps avoiding rounding problems (integral part of pos is usually 5 digits, 0.05 is about as low as we can go)
	// example: ceil(afterseveralvertextransformations(y = 133)) => 134 => line 133 stays empty
	// input granularity is 1/16 pixel, anything smaller than that won't step drawing up/left by one pixel
	// example: 133.0625 (133 + 1/16) should start from line 134, ceil(133.0625 - 0.05) still above 133
	
	float4 p = float4(input.p, input.z, 0) - float4(0.05f, 0.05f, 0, 0); 

	output.p = p * VertexScale - VertexOffset;
#if VS_RTCOPY
	output.tp = (p * VertexScale - VertexOffset) * float4(0.5, -0.5, 0, 0) + 0.5;
#endif

	if(VS_TME)
	{
		if(VS_FST)
		{
			output.t.xy = input.uv * TextureScale;
			output.t.w = 1.0f;
		}
		else
		{
			output.t.xy = input.st;
			output.t.w = input.q;
		}
	}
	else
	{
		output.t.xy = 0;
		output.t.w = 1.0f;
	}

	output.c = input.c;
	output.t.z = input.f.r;

	return output;
}

#if GS_PRIM == 0

[maxvertexcount(1)]
void gs_main(point VS_OUTPUT input[1], inout PointStream<VS_OUTPUT> stream)
{
	stream.Append(input[0]);
}

#elif GS_PRIM == 1

[maxvertexcount(2)]
void gs_main(line VS_OUTPUT input[2], inout LineStream<VS_OUTPUT> stream)
{
	#if GS_IIP == 0
	input[0].c = input[1].c;
	#endif

	stream.Append(input[0]);
	stream.Append(input[1]);
}

#elif GS_PRIM == 2

[maxvertexcount(3)]
void gs_main(triangle VS_OUTPUT input[3], inout TriangleStream<VS_OUTPUT> stream)
{
	#if GS_IIP == 0
	input[0].c = input[2].c;
	input[1].c = input[2].c;
	#endif

	stream.Append(input[0]);
	stream.Append(input[1]);
	stream.Append(input[2]);
}

#elif GS_PRIM == 3

[maxvertexcount(4)]
void gs_main(line VS_OUTPUT input[2], inout TriangleStream<VS_OUTPUT> stream)
{
	input[0].p.z = input[1].p.z;
	input[0].t.zw = input[1].t.zw;

	#if GS_IIP == 0
	input[0].c = input[1].c;
	#endif

	VS_OUTPUT lb = input[1];

	lb.p.x = input[0].p.x;
	lb.t.x = input[0].t.x;

	VS_OUTPUT rt = input[1];

	rt.p.y = input[0].p.y;
	rt.t.y = input[0].t.y;

	stream.Append(input[0]);
	stream.Append(lb);
	stream.Append(rt);
	stream.Append(input[1]);
}

#endif

PS_OUTPUT ps_main(PS_INPUT input)
{
	float4 c = ps_color(input);

	PS_OUTPUT output;

	output.c1 = c.a * 2; // used for alpha blending

	if(PS_AOUT) // 16 bit output
	{
		float a = 128.0f / 255; // alpha output will be 0x80
		
		c.a = PS_FBA ? a : step(0.5, c.a) * a;
	}
	else if(PS_FBA)
	{
		if(c.a < 0.5) c.a += 0.5;
	}

	output.c0 = c;

	return output;
}

#elif SHADER_MODEL <= 0x300

VS_OUTPUT vs_main(VS_INPUT input)
{
	if(VS_BPPZ == 1) // 24
	{
		input.p.z = fmod(input.p.z, 0x1000000); 
	}
	else if(VS_BPPZ == 2) // 16
	{
		input.p.z = fmod(input.p.z, 0x10000);
	}

	VS_OUTPUT output;
	
	// pos -= 0.05 (1/320 pixel) helps avoiding rounding problems (integral part of pos is usually 5 digits, 0.05 is about as low as we can go)
	// example: ceil(afterseveralvertextransformations(y = 133)) => 134 => line 133 stays empty
	// input granularity is 1/16 pixel, anything smaller than that won't step drawing up/left by one pixel
	// example: 133.0625 (133 + 1/16) should start from line 134, ceil(133.0625 - 0.05) still above 133

	float4 p = input.p - float4(0.05f, 0.05f, 0, 0);

	output.p = p * VertexScale - VertexOffset;
#if VS_RTCOPY
	output.tp = (p * VertexScale - VertexOffset) * float4(0.5, -0.5, 0, 0) + 0.5;
#endif

	if(VS_LOGZ)
	{
		output.p.z = log2(1.0f + input.p.z) / 32;
	}
	
	if(VS_TME)
	{
		if(VS_FST)
		{
            output.t.xy = input.t * TextureScale;
			output.t.w = 1.0f;
		}
		else
		{
			output.t.xy = input.t;
			output.t.w = input.p.w;
		}
	}
	else
	{
		output.t.xy = 0;
		output.t.w = 1.0f;
	}

	output.c = input.c;
	output.t.z = input.f.b;
	
	return output;
}

float4 ps_main(PS_INPUT input) : COLOR
{
	float4 c = ps_color(input);

	c.a *= 2;

	return c;
}

#endif
#endif
   .      ��
 ��'    0	        #ifdef SHADER_MODEL // make safe to include in resource file to enforce dependency
#if SHADER_MODEL >= 0x400

struct VS_INPUT
{
	float4 p : POSITION; 
	float2 t : TEXCOORD0;
};

struct VS_OUTPUT
{
	float4 p : SV_Position;
	float2 t : TEXCOORD0;
};

Texture2D Texture;
SamplerState TextureSampler;

float4 sample_c(float2 uv)
{
	return Texture.Sample(TextureSampler, uv);
}

struct PS_INPUT
{
	float4 p : SV_Position;
	float2 t : TEXCOORD0;
};

struct PS_OUTPUT
{
	float4 c : SV_Target0;
};

#elif SHADER_MODEL <= 0x300

struct VS_INPUT
{
	float4 p : POSITION; 
	float2 t : TEXCOORD0;
};

struct VS_OUTPUT
{
	float4 p : POSITION;
	float2 t : TEXCOORD0;
};

struct PS_INPUT
{
#if SHADER_MODEL < 0x300
	float4 p : TEXCOORD1;
#else
	float4 p : VPOS;
#endif
	float2 t : TEXCOORD0;
};

struct PS_OUTPUT
{
	float4 c : COLOR;
};

sampler Texture : register(s0);

float4 sample_c(float2 uv)
{
	return tex2D(Texture, uv);
}

#endif

VS_OUTPUT vs_main(VS_INPUT input)
{
	VS_OUTPUT output;

	output.p = input.p;
	output.t = input.t;

	return output;
}

PS_OUTPUT ps_main0(PS_INPUT input)
{
	PS_OUTPUT output;
	
	output.c = sample_c(input.t);

	return output;
}

PS_OUTPUT ps_main7(PS_INPUT input)
{
	PS_OUTPUT output;
	
	float4 c = sample_c(input.t);
	
	c.a = dot(c.rgb, float3(0.299, 0.587, 0.114));

	output.c = c;

	return output;
}

float4 ps_crt(PS_INPUT input, int i)
{
	float4 mask[4] = 
	{
		float4(1, 0, 0, 0), 
		float4(0, 1, 0, 0), 
		float4(0, 0, 1, 0), 
		float4(1, 1, 1, 0)
	};
	
	return sample_c(input.t) * saturate(mask[i] + 0.5f);
}

float4 ps_scanlines(PS_INPUT input, int i)
{
	float4 mask[2] =
	{
		float4(1, 1, 1, 0),
		float4(0, 0, 0, 0)
	};

	return sample_c(input.t) * saturate(mask[i] + 0.5f);
}

#if SHADER_MODEL >= 0x400

uint ps_main1(PS_INPUT input) : SV_Target0
{
	float4 c = sample_c(input.t);

	c.a *= 256.0f / 127; // hm, 0.5 won't give us 1.0 if we just multiply with 2

	uint4 i = c * float4(0x001f, 0x03e0, 0x7c00, 0x8000);

	return (i.x & 0x001f) | (i.y & 0x03e0) | (i.z & 0x7c00) | (i.w & 0x8000);	
}

PS_OUTPUT ps_main2(PS_INPUT input)
{
	PS_OUTPUT output;
	
	clip(sample_c(input.t).a - 127.5f / 255); // >= 0x80 pass
	
	output.c = 0;

	return output;
}

PS_OUTPUT ps_main3(PS_INPUT input)
{
	PS_OUTPUT output;
	
	clip(127.5f / 255 - sample_c(input.t).a); // < 0x80 pass (== 0x80 should not pass)
	
	output.c = 0;

	return output;
}

PS_OUTPUT ps_main4(PS_INPUT input)
{
	PS_OUTPUT output;
	
	output.c = fmod(sample_c(input.t) * 255 + 0.5f, 256) / 255;

	return output;
}

PS_OUTPUT ps_main5(PS_INPUT input) // scanlines
{
	PS_OUTPUT output;
	
	uint4 p = (uint4)input.p;

	output.c = ps_scanlines(input, p.y % 2);

	return output;
}

PS_OUTPUT ps_main6(PS_INPUT input) // diagonal
{
	PS_OUTPUT output;

	uint4 p = (uint4)input.p;

	output.c = ps_crt(input, (p.x + (p.y % 3)) % 3);

	return output;
}

PS_OUTPUT ps_main8(PS_INPUT input) // triangular
{
	PS_OUTPUT output;

	uint4 p = (uint4)input.p;

	// output.c = ps_crt(input, ((p.x + (p.y & 1) * 3) >> 1) % 3); 
	output.c = ps_crt(input, ((p.x + ((p.y >> 1) & 1) * 3) >> 1) % 3);

	return output;
}

static const float PI = 3.14159265359f;
PS_OUTPUT ps_main9(PS_INPUT input) // triangular
{
	PS_OUTPUT output;

	float2 texdim, halfpixel; 
	Texture.GetDimensions(texdim.x, texdim.y); 
	if (ddy(input.t.y) * texdim.y > 0.5) 
		output.c = sample_c(input.t); 
	else
		output.c = (0.9 - 0.4 * cos(2 * PI * input.t.y * texdim.y)) * sample_c(float2(input.t.x, (floor(input.t.y * texdim.y) + 0.5) / texdim.y));

	return output;
}

#elif SHADER_MODEL <= 0x300

PS_OUTPUT ps_main1(PS_INPUT input)
{
	PS_OUTPUT output;
	
	float4 c = sample_c(input.t);
	
	c.a *= 128.0f / 255; // *= 0.5f is no good here, need to do this in order to get 0x80 for 1.0f (instead of 0x7f)
	
	output.c = c;

	return output;
}

PS_OUTPUT ps_main2(PS_INPUT input)
{
	PS_OUTPUT output;
	
	clip(sample_c(input.t).a - 255.0f / 255); // >= 0x80 pass
	
	output.c = 0;

	return output;
}

PS_OUTPUT ps_main3(PS_INPUT input)
{
	PS_OUTPUT output;
	
	clip(254.95f / 255 - sample_c(input.t).a); // < 0x80 pass (== 0x80 should not pass)
	
	output.c = 0;

	return output;
}

PS_OUTPUT ps_main4(PS_INPUT input)
{
	PS_OUTPUT output;
	
	output.c = 1;
	
	return output;
}

PS_OUTPUT ps_main5(PS_INPUT input) // scanlines
{
	PS_OUTPUT output;
	
	int4 p = (int4)input.p;

	output.c = ps_scanlines(input, p.y % 2);

	return output;
}

PS_OUTPUT ps_main6(PS_INPUT input) // diagonal
{
	PS_OUTPUT output;

	int4 p = (int4)input.p;

	output.c = ps_crt(input, (p.x + (p.y % 3)) % 3);

	return output;
}

PS_OUTPUT ps_main8(PS_INPUT input) // triangular
{
	PS_OUTPUT output;

	int4 p = (int4)input.p;

	// output.c = ps_crt(input, ((p.x + (p.y % 2) * 3) / 2) % 3);
	output.c = ps_crt(input, ((p.x + ((p.y / 2) % 2) * 3) / 2) % 3);

	return output;
}

static const float PI = 3.14159265359f;
PS_OUTPUT ps_main9(PS_INPUT input) // triangular
{
	PS_OUTPUT output;

	// Needs DX9 conversion
	/*float2 texdim, halfpixel; 
	Texture.GetDimensions(texdim.x, texdim.y); 
	if (ddy(input.t.y) * texdim.y > 0.5) 
		output.c = sample_c(input.t); 
	else
		output.c = (0.5 - 0.5 * cos(2 * PI * input.t.y * texdim.y)) * sample_c(float2(input.t.x, (floor(input.t.y * texdim.y) + 0.5) / texdim.y));
*/

	// replacement shader
	int4 p = (int4)input.p;
	output.c = ps_crt(input, ((p.x + ((p.y / 2) % 2) * 3) / 2) % 3);

	return output;
}

#endif
#endif
  p{      ��
 ��'    0	        #ifdef SHADER_MODEL // make safe to include in resource file to enforce dependency

float4 GetConfig()
{
	return float4( %s, %s, %s, 1.0 );
}

#if SHADER_MODEL >= 0x400

Texture2D Texture;
SamplerState Sampler;

cbuffer cb0
{
	float2 ZrH;
	float hH;
	float fSaturation;
};

struct PS_INPUT
{
	float4 p : SV_Position;
	float2 t : TEXCOORD0;
};

float4 ps_main0(PS_INPUT input) : SV_Target0
{
	clip(frac(input.t.y * hH) - 0.5);

	float4 c1 = Texture.Sample(Sampler, input.t);
	float4 c2 = c1;
	float4 c3 = c1;
	float4 c4 = c1;
	float4 c5 = c1;
	float4 c0=GetConfig();

	//Gens32 Filter Copyrights 2004-2011 DarkDancer
	/////////////////////////////////////////////////////////////////////
	float gY=c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( c0.z>0 )
	{
		float4 fA0 = Texture.Sample(Sampler, input.t - ZrH);
		float4 fA1 = Texture.Sample(Sampler, input.t + ZrH);

		//c2 = min( fA0,fA1 );
		//c3 = max( fA0,fA1 );

		////c2 = (fA0+fA1+fA2+fA3)/4;
		////c3 = (fA0+fA1+fA2+fA3)/4;

		//float gMin = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		//float gMax = c3.r*0.299+c3.g*0.587+c3.b*0.114;

		//if( gY < (gMin+gMax)/2 )
		//	c1 = c1*gY/gMin;
		//if( gY>(gMin+gMax)/2 )
		//	c1 = c1*gY/gMax;
		//if( gY<(gMin+gMax)/2 )
		//	c1=c1*0.975;
		//else
		//	c1=c1*1.025;
		c2 =( max( fA0,fA1 )*2+c1)/3;
		float gYC = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		c1=(c1*gY/gYC);

		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.r*0.299+c1.g*0.587+c1.b*0.114; 
	}
	////////////////////////////////////////////////////////////////////////
	//float gY = c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( fSaturation<0 )
	{
		return c1;
	}

	if( fSaturation>4 && fSaturation<6 )	//5�ڰ�ģʽ��
	{
		c2.b = gY;
		c2.g = gY;
		c2.r = gY;
		//���ȵ���;

		c2 = c0.x*c2;
		return c2;
	}

	//float fat = c2.g/gY*0.245272;
	//if( c2.g<(c2.r+c2.b)*0.5 )
	//	fat = -c2.g/gY*0.245272;

	float fat = 0;

	if( fSaturation>9 && fSaturation<11 )	//G mode.
	{
		//c2.b = gY+1.403*gCr+0.344*gCb;
		//c2.g = gY*(1.0+(gCb+gCr))- 0.344*gCb + 0.344*gCr;
		//c2.r = gY+1.770*gCb+0.714*gCr;

		//c2.b = ( c2.b + c1.b )/2;
		//c2.g = max( c2.g , c1.g );
		//c2.r = ( c2.r + c1.r )/2;

		//c2.b = gY*0.309724+0.690276*c1.b;
		//c2.g = gY*1.59656 - 0.245272*c1.r  - 0.351288*c1.b;
		//c2.r = 1.26201*c1.r-0.26201*gY;

		//Good color.
		//fat = -c2.b/gY*c0.y;
		//c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = c2.g/gY*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		//fat = c2.r/gY*c0.y;
		//c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c2.b/gY*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c2.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) - (0.245272+fat*0.245272/0.59656)*c1.r  + (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.r/gY*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		c4.b = c3.b;	//��Bֵ��
		fat = c2.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>0 && fSaturation<2 )	//Advanceģʽ��
	{
		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.b*0.299+c1.r*0.587+c1.g*0.114; 

		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c3=c2;

		gY = c1.r*0.299+c1.b*0.587+c1.g*0.114; 
		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c4.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c2.b = (c3.b+c4.b)/2;
		c2.g = c1.g;
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>2 && fSaturation<4 )	//3,���ģʽ
	{
		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c3.r = gY*(0.309724+fat)+(0.690276-fat)*c1.r;
		fat = c1.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) + (0.245272+fat*0.245272/0.59656)*c1.b  - (0.351288+fat*0.351288/0.59656)*c1.r;
		fat = c1.b/gY*c0.y;
		c3.b = (1.26201+fat)*c1.b-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c1.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c1.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}


	//9����ģʽ��
	fat = -sin(c2.b/gY)*c0.y;
	c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
	fat = sin(c2.g/gY)*c0.y;
	c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
	fat = sin(c2.r/gY)*c0.y;
	c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

	//���ȵ���;
	return c0.x*c2;
}

float4 ps_main1(PS_INPUT input) : SV_Target0
{
	clip(0.5 - frac(input.t.y * hH));

	//return Texture.Sample(Sampler, input.t);

	float4 c1 = Texture.Sample(Sampler, input.t);
	float4 c2 = c1;
	float4 c3 = c1;
	float4 c4 = c1;
	float4 c5 = c1;

	float4 c0=GetConfig();

	//Gens32 Filter Copyrights 2004-2011 DarkDancer
	/////////////////////////////////////////////////////////////////////
	float gY=c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( c0.z>0 )
	{
		float4 fA0 = Texture.Sample(Sampler, input.t - ZrH);
		float4 fA1 = Texture.Sample(Sampler, input.t + ZrH);

		//c2 = min( fA0,fA1 );
		//c3 = max( fA0,fA1 );

		////c2 = (fA0+fA1+fA2+fA3)/4;
		////c3 = (fA0+fA1+fA2+fA3)/4;

		//float gMin = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		//float gMax = c3.r*0.299+c3.g*0.587+c3.b*0.114;

		//if( gY < (gMin+gMax)/2 )
		//	c1 = c1*gY/gMin;
		//if( gY>(gMin+gMax)/2 )
		//	c1 = c1*gY/gMax;
		//if( gY<(gMin+gMax)/2 )
		//	c1=c1*0.975;
		//else
		//	c1=c1*1.025;
		c2 =( max( fA0,fA1 )*2+c1)/3;
		float gYC = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		c1=(c1*gY/gYC);

		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.r*0.299+c1.g*0.587+c1.b*0.114; 
	}
	////////////////////////////////////////////////////////////////////////
	//float gY = c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( fSaturation<0 )
	{
		return c1;
	}

	if( fSaturation>4 && fSaturation<6 )	//5�ڰ�ģʽ��
	{
		c2.b = gY;
		c2.g = gY;
		c2.r = gY;
		//���ȵ���;

		c2 = c0.x*c2;
		return c2;
	}
	//float fat = c2.g/gY*0.245272;
	//if( c2.g<(c2.r+c2.b)*0.5 )
	//	fat = -c2.g/gY*0.245272;

	float fat = 0;

	if( fSaturation>9 && fSaturation<11 )	//G mode.
	{
		//c2.b = gY+1.403*gCr+0.344*gCb;
		//c2.g = gY*(1.0+(gCb+gCr))- 0.344*gCb + 0.344*gCr;
		//c2.r = gY+1.770*gCb+0.714*gCr;

		//c2.b = ( c2.b + c1.b )/2;
		//c2.g = max( c2.g , c1.g );
		//c2.r = ( c2.r + c1.r )/2;

		//c2.b = gY*0.309724+0.690276*c1.b;
		//c2.g = gY*1.59656 - 0.245272*c1.r  - 0.351288*c1.b;
		//c2.r = 1.26201*c1.r-0.26201*gY;

		//Good color.
		//fat = -c2.b/gY*c0.y;
		//c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = c2.g/gY*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		//fat = c2.r/gY*c0.y;
		//c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c2.b/gY*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c2.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) - (0.245272+fat*0.245272/0.59656)*c1.r  + (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.r/gY*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		c4.b = c3.b;	//��Bֵ��
		fat = c2.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>0 && fSaturation<2 )	//Advanceģʽ��
	{
		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.b*0.299+c1.r*0.587+c1.g*0.114; 

		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c3=c2;

		gY = c1.r*0.299+c1.b*0.587+c1.g*0.114; 
		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c4.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c2.b = (c3.b+c4.b)/2;
		c2.g = c1.g;
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>2 && fSaturation<4 )	//3,���ģʽ
	{
		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c3.r = gY*(0.309724+fat)+(0.690276-fat)*c1.r;
		fat = c1.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) + (0.245272+fat*0.245272/0.59656)*c1.b  - (0.351288+fat*0.351288/0.59656)*c1.r;
		fat = c1.b/gY*c0.y;
		c3.b = (1.26201+fat)*c1.b-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c1.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c1.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}


	//9����ģʽ��
	fat = -sin(c2.b/gY)*c0.y;
	c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
	fat = sin(c2.g/gY)*c0.y;
	c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
	fat = sin(c2.r/gY)*c0.y;
	c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

	//���ȵ���;
	return c0.x*c2;
}

float4 ps_main2(PS_INPUT input) : SV_Target0
{
	float4 c0 = Texture.Sample(Sampler, input.t - ZrH);
	float4 c1 = Texture.Sample(Sampler, input.t);
	float4 c2 = Texture.Sample(Sampler, input.t + ZrH);

	return (c0 + c1 * 2 + c2) / 4;
}

float4 ps_main3(PS_INPUT input) : SV_Target0
{
	//return Texture.Sample(Sampler, input.t);

	float4 c1 = Texture.Sample(Sampler, input.t);
	float4 c2 = c1;
	float4 c3 = c1;
	float4 c4 = c1;
	float4 c5 = c1;

	float4 c0=GetConfig();


	//Gens32 Filter Copyrights 2004-2011 DarkDancer
	/////////////////////////////////////////////////////////////////////
	float gY=c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( c0.z>0 )
	{
		float4 fA0 = Texture.Sample(Sampler, input.t - ZrH);
		float4 fA1 = Texture.Sample(Sampler, input.t + ZrH);

		//c2 = min( fA0,fA1 );
		//c3 = max( fA0,fA1 );

		////c2 = (fA0+fA1+fA2+fA3)/4;
		////c3 = (fA0+fA1+fA2+fA3)/4;

		//float gMin = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		//float gMax = c3.r*0.299+c3.g*0.587+c3.b*0.114;

		//if( gY < (gMin+gMax)/2 )
		//	c1 = c1*gY/gMin;
		//if( gY>(gMin+gMax)/2 )
		//	c1 = c1*gY/gMax;
		//if( gY<(gMin+gMax)/2 )
		//	c1=c1*0.975;
		//else
		//	c1=c1*1.025;
		c2 =( max( fA0,fA1 )*2+c1)/3;
		float gYC = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		c1=(c1*gY/gYC);

		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.r*0.299+c1.g*0.587+c1.b*0.114; 
	}
	////////////////////////////////////////////////////////////////////////
	//float gY = c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( fSaturation<0 )
	{
		return c1;
	}

	if( fSaturation>4 && fSaturation<6 )	//5�ڰ�ģʽ��
	{
		c2.b = gY;
		c2.g = gY;
		c2.r = gY;
		//���ȵ���;

		c2 = c0.x*c2;
		return c2;
	}
	//float fat = c2.g/gY*0.245272;
	//if( c2.g<(c2.r+c2.b)*0.5 )
	//	fat = -c2.g/gY*0.245272;

	float fat = 0;

	if( fSaturation>9 && fSaturation<11 )	//G mode.
	{
		//c2.b = gY+1.403*gCr+0.344*gCb;
		//c2.g = gY*(1.0+(gCb+gCr))- 0.344*gCb + 0.344*gCr;
		//c2.r = gY+1.770*gCb+0.714*gCr;

		//c2.b = ( c2.b + c1.b )/2;
		//c2.g = max( c2.g , c1.g );
		//c2.r = ( c2.r + c1.r )/2;

		//c2.b = gY*0.309724+0.690276*c1.b;
		//c2.g = gY*1.59656 - 0.245272*c1.r  - 0.351288*c1.b;
		//c2.r = 1.26201*c1.r-0.26201*gY;

		//Good color.
		//fat = -c2.b/gY*c0.y;
		//c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = c2.g/gY*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		//fat = c2.r/gY*c0.y;
		//c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c2.b/gY*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c2.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) - (0.245272+fat*0.245272/0.59656)*c1.r  + (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.r/gY*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		c4.b = c3.b;	//��Bֵ��
		fat = c2.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>0 && fSaturation<2 )	//Advanceģʽ��
	{
		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.b*0.299+c1.r*0.587+c1.g*0.114; 

		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c3=c2;

		gY = c1.r*0.299+c1.b*0.587+c1.g*0.114; 
		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c4.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c2.b = (c3.b+c4.b)/2;
		c2.g = c1.g;
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>2 && fSaturation<4 )	//3,���ģʽ
	{
		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c3.r = gY*(0.309724+fat)+(0.690276-fat)*c1.r;
		fat = c1.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) + (0.245272+fat*0.245272/0.59656)*c1.b  - (0.351288+fat*0.351288/0.59656)*c1.r;
		fat = c1.b/gY*c0.y;
		c3.b = (1.26201+fat)*c1.b-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c1.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c1.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}


	//9����ģʽ��
	fat = -sin(c1.b/gY)*c0.y;
	c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
	fat = sin(c1.g/gY)*c0.y;
	c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
	fat = sin(c1.r/gY)*c0.y;
	c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

	//���ȵ���;
	return c0.x*c2;
}

#elif SHADER_MODEL <= 0x300

sampler s0 : register(s0);

float4 Params1 : register(c0);

#define ZrH (Params1.xy)
#define hH  (Params1.z)
#define fSaturation (Params1.w)

float4 ps_main0(float2 tex : TEXCOORD0) : COLOR
{
	clip(frac(tex.y * hH) - 0.5);

	//return tex2D(s0, tex);

	float4 c1 = tex2D(s0, tex);
	float4 c2 = c1;
	float4 c3 = c1;
	float4 c4 = c1;
	float4 c5 = c1;

	float4 c0=GetConfig();

	//Gens32 Filter Copyrights 2004-2011 DarkDancer
	/////////////////////////////////////////////////////////////////////
	float gY=c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( c0.z>0 )
	{
		float4 fA0 = tex2D(s0, tex - ZrH);
		float4 fA1 = tex2D(s0, tex + ZrH);

		//c2 = min( fA0,fA1 );
		//c3 = max( fA0,fA1 );

		////c2 = (fA0+fA1+fA2+fA3)/4;
		////c3 = (fA0+fA1+fA2+fA3)/4;

		//float gMin = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		//float gMax = c3.r*0.299+c3.g*0.587+c3.b*0.114;

		//if( gY < (gMin+gMax)/2 )
		//	c1 = c1*gY/gMin;
		//if( gY>(gMin+gMax)/2 )
		//	c1 = c1*gY/gMax;
		//if( gY<(gMin+gMax)/2 )
		//	c1=c1*0.975;
		//else
		//	c1=c1*1.025;
		c2 =( max( fA0,fA1 )*2+c1)/3;
		float gYC = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		c1=(c1*gY/gYC);

		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.r*0.299+c1.g*0.587+c1.b*0.114; 
	}
	////////////////////////////////////////////////////////////////////////
	//float gY = c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( fSaturation<0 )
	{
		return c1;
	}

	if( fSaturation>4 && fSaturation<6 )	//5�ڰ�ģʽ��
	{
		c2.b = gY;
		c2.g = gY;
		c2.r = gY;
		//���ȵ���;

		c2 = c0.x*c2;
		return c2;
	}
	//float fat = c2.g/gY*0.245272;
	//if( c2.g<(c2.r+c2.b)*0.5 )
	//	fat = -c2.g/gY*0.245272;

	float fat = 0;

	if( fSaturation>9 && fSaturation<11 )	//G mode.
	{
		//c2.b = gY+1.403*gCr+0.344*gCb;
		//c2.g = gY*(1.0+(gCb+gCr))- 0.344*gCb + 0.344*gCr;
		//c2.r = gY+1.770*gCb+0.714*gCr;

		//c2.b = ( c2.b + c1.b )/2;
		//c2.g = max( c2.g , c1.g );
		//c2.r = ( c2.r + c1.r )/2;

		//c2.b = gY*0.309724+0.690276*c1.b;
		//c2.g = gY*1.59656 - 0.245272*c1.r  - 0.351288*c1.b;
		//c2.r = 1.26201*c1.r-0.26201*gY;

		//Good color.
		//fat = -c2.b/gY*c0.y;
		//c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = c2.g/gY*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		//fat = c2.r/gY*c0.y;
		//c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c2.b/gY*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c2.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) - (0.245272+fat*0.245272/0.59656)*c1.r  + (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.r/gY*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		c4.b = c3.b;	//��Bֵ��
		fat = c2.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>0 && fSaturation<2 )	//Advanceģʽ��
	{
		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.b*0.299+c1.r*0.587+c1.g*0.114; 

		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c3=c2;

		gY = c1.r*0.299+c1.b*0.587+c1.g*0.114; 
		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c4.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c2.b = (c3.b+c4.b)/2;
		c2.g = c1.g;
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>2 && fSaturation<4 )	//3,���ģʽ
	{
		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c3.r = gY*(0.309724+fat)+(0.690276-fat)*c1.r;
		fat = c1.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) + (0.245272+fat*0.245272/0.59656)*c1.b  - (0.351288+fat*0.351288/0.59656)*c1.r;
		fat = c1.b/gY*c0.y;
		c3.b = (1.26201+fat)*c1.b-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c1.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c1.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}


	//9����ģʽ��
	fat = -sin(c2.b/gY)*c0.y;
	c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
	fat = sin(c2.g/gY)*c0.y;
	c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
	fat = sin(c2.r/gY)*c0.y;
	c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

	//���ȵ���;
	return c0.x*c2;
}

float4 ps_main1(float2 tex : TEXCOORD0) : COLOR
{
	clip(0.5 - frac(tex.y * hH));

	float4 c1 = tex2D(s0, tex);
	float4 c2 = c1;
	float4 c3 = c1;
	float4 c4 = c1;
	float4 c5 = c1;

	float4 c0=GetConfig();

	//Gens32 Filter Copyrights 2004-2011 DarkDancer
	/////////////////////////////////////////////////////////////////////
	float gY=c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( c0.z>0 )
	{
		float4 fA0 = tex2D(s0, tex - ZrH);
		float4 fA1 = tex2D(s0, tex + ZrH);

		//c2 = min( fA0,fA1 );
		//c3 = max( fA0,fA1 );

		////c2 = (fA0+fA1+fA2+fA3)/4;
		////c3 = (fA0+fA1+fA2+fA3)/4;

		//float gMin = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		//float gMax = c3.r*0.299+c3.g*0.587+c3.b*0.114;

		//if( gY < (gMin+gMax)/2 )
		//	c1 = c1*gY/gMin;
		//if( gY>(gMin+gMax)/2 )
		//	c1 = c1*gY/gMax;
		//if( gY<(gMin+gMax)/2 )
		//	c1=c1*0.975;
		//else
		//	c1=c1*1.025;
		c2 =( max( fA0,fA1 )*2+c1)/3;
		float gYC = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		c1=(c1*gY/gYC);

		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.r*0.299+c1.g*0.587+c1.b*0.114; 
	}
	////////////////////////////////////////////////////////////////////////
	//float gY = c1.r*0.299+c1.g*0.587+c1.b*0.114;


	if( fSaturation<0 )
	{
		return c1;
	}

	if( fSaturation>4 && fSaturation<6 )	//5�ڰ�ģʽ��
	{
		c2.b = gY;
		c2.g = gY;
		c2.r = gY;
		//���ȵ���;

		c2 = c0.x*c2;
		return c2;
	}
	//float fat = c2.g/gY*0.245272;
	//if( c2.g<(c2.r+c2.b)*0.5 )
	//	fat = -c2.g/gY*0.245272;

	float fat = 0;

	if( fSaturation>9 && fSaturation<11 )	//G mode.
	{
		//c2.b = gY+1.403*gCr+0.344*gCb;
		//c2.g = gY*(1.0+(gCb+gCr))- 0.344*gCb + 0.344*gCr;
		//c2.r = gY+1.770*gCb+0.714*gCr;

		//c2.b = ( c2.b + c1.b )/2;
		//c2.g = max( c2.g , c1.g );
		//c2.r = ( c2.r + c1.r )/2;

		//c2.b = gY*0.309724+0.690276*c1.b;
		//c2.g = gY*1.59656 - 0.245272*c1.r  - 0.351288*c1.b;
		//c2.r = 1.26201*c1.r-0.26201*gY;

		//Good color.
		//fat = -c2.b/gY*c0.y;
		//c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = c2.g/gY*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		//fat = c2.r/gY*c0.y;
		//c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c2.b/gY*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c2.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) - (0.245272+fat*0.245272/0.59656)*c1.r  + (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.r/gY*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		c4.b = c3.b;	//��Bֵ��
		fat = c2.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>0 && fSaturation<2 )	//Advanceģʽ��
	{
		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.b*0.299+c1.r*0.587+c1.g*0.114; 

		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c3=c2;

		gY = c1.r*0.299+c1.b*0.587+c1.g*0.114; 
		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c4.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c2.b = (c3.b+c4.b)/2;
		c2.g = c1.g;
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>2 && fSaturation<4 )	//3,���ģʽ
	{
		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c3.r = gY*(0.309724+fat)+(0.690276-fat)*c1.r;
		fat = c1.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) + (0.245272+fat*0.245272/0.59656)*c1.b  - (0.351288+fat*0.351288/0.59656)*c1.r;
		fat = c1.b/gY*c0.y;
		c3.b = (1.26201+fat)*c1.b-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c1.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c1.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}


	//9����ģʽ��
	fat = -sin(c2.b/gY)*c0.y;
	c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
	fat = sin(c2.g/gY)*c0.y;
	c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
	fat = sin(c2.r/gY)*c0.y;
	c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

	//���ȵ���;
	return c0.x*c2;
}

float4 ps_main2(float2 tex : TEXCOORD0) : COLOR
{
	float4 c0 = tex2D(s0, tex - ZrH);
	float4 c1 = tex2D(s0, tex);
	float4 c2 = tex2D(s0, tex + ZrH);

	return (c0 + c1 * 2 + c2) / 4;
}

float4 ps_main3(float2 tex : TEXCOORD0) : COLOR
{
	//return tex2D(s0, tex);

	float4 c1 = tex2D(s0, tex);
	float4 c2 = c1;
	float4 c3 = c1;
	float4 c4 = c1;
	float4 c5 = c1;

	float4 c0=GetConfig();

	//Gens32 Filter Copyrights 2004-2011 DarkDancer
	/////////////////////////////////////////////////////////////////////
	float gY=c1.r*0.299+c1.g*0.587+c1.b*0.114;

	if( c0.z>0 )
	{
		float4 fA0 = tex2D(s0, tex - ZrH);
		float4 fA1 = tex2D(s0, tex + ZrH);

		//c2 = min( fA0,fA1 );
		//c3 = max( fA0,fA1 );

		////c2 = (fA0+fA1+fA2+fA3)/4;
		////c3 = (fA0+fA1+fA2+fA3)/4;

		//float gMin = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		//float gMax = c3.r*0.299+c3.g*0.587+c3.b*0.114;

		//if( gY < (gMin+gMax)/2 )
		//	c1 = c1*gY/gMin;
		//if( gY>(gMin+gMax)/2 )
		//	c1 = c1*gY/gMax;
		//if( gY<(gMin+gMax)/2 )
		//	c1=c1*0.975;
		//else
		//	c1=c1*1.025;
		c2 =( max( fA0,fA1 )*2+c1)/3;
		float gYC = c2.r*0.299+c2.g*0.587+c2.b*0.114; 
		c1=(c1*gY/gYC);

		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.r*0.299+c1.g*0.587+c1.b*0.114; 
	}
	////////////////////////////////////////////////////////////////////////
	//float gY = c1.r*0.299+c1.g*0.587+c1.b*0.114;


	if( fSaturation<0 )
	{
		return c1;
	}

	if( fSaturation>4 && fSaturation<6 )	//5�ڰ�ģʽ��
	{
		c2.b = gY;
		c2.g = gY;
		c2.r = gY;
		//���ȵ���;

		c2 = c0.x*c2;
		return c2;
	}
	//float fat = c2.g/gY*0.245272;
	//if( c2.g<(c2.r+c2.b)*0.5 )
	//	fat = -c2.g/gY*0.245272;

	float fat = 0;

	if( fSaturation>9 && fSaturation<11 )	//G mode.
	{
		//c2.b = gY+1.403*gCr+0.344*gCb;
		//c2.g = gY*(1.0+(gCb+gCr))- 0.344*gCb + 0.344*gCr;
		//c2.r = gY+1.770*gCb+0.714*gCr;

		//c2.b = ( c2.b + c1.b )/2;
		//c2.g = max( c2.g , c1.g );
		//c2.r = ( c2.r + c1.r )/2;

		//c2.b = gY*0.309724+0.690276*c1.b;
		//c2.g = gY*1.59656 - 0.245272*c1.r  - 0.351288*c1.b;
		//c2.r = 1.26201*c1.r-0.26201*gY;

		//Good color.
		//fat = -c2.b/gY*c0.y;
		//c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = c2.g/gY*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		//fat = c2.r/gY*c0.y;
		//c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c2.b/gY*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c2.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) - (0.245272+fat*0.245272/0.59656)*c1.r  + (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.r/gY*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		//��ɫȡ��
		c4.b = c3.b;	//��Bֵ��
		fat = c2.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c2.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>0 && fSaturation<2 )	//Advanceģʽ��
	{
		//c1 = c2;
		//float gY = c3.r*0.299+c3.g*0.587+c3.b*0.114;
		gY = c1.b*0.299+c1.r*0.587+c1.g*0.114; 

		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c3.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c3.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c3=c2;

		gY = c1.r*0.299+c1.b*0.587+c1.g*0.114; 
		//9����ģʽ��
		fat = -(c1.b/gY)*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		//fat = sin(c1.g/gY)*c0.y;
		//c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = (c1.r/gY)*c0.y;
		c4.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

		c2.b = (c3.b+c4.b)/2;
		c2.g = c1.g;
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}

	if( fSaturation>2 && fSaturation<4 )	//3,���ģʽ
	{
		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c3.r = gY*(0.309724+fat)+(0.690276-fat)*c1.r;
		fat = c1.g/gY*c0.y;
		c3.g = gY*(1.59656+fat-(0.351288+fat*0.351288/0.59656)*2) + (0.245272+fat*0.245272/0.59656)*c1.b  - (0.351288+fat*0.351288/0.59656)*c1.r;
		fat = c1.b/gY*c0.y;
		c3.b = (1.26201+fat)*c1.b-(0.26201+fat)*gY;

		//��ɫȡ��
		fat = -c1.b/gY*c0.y;
		c4.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
		fat = c1.r/gY*c0.y;
		c4.r = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.g  - (0.351288+fat*0.351288/0.59656)*c1.b;
		fat = c1.g/gY*c0.y;
		c4.g = (1.26201+fat)*c1.g-(0.26201+fat)*gY;

		c2.b = min(c3.b,c4.b);
		c2.g = max(c3.g,c4.g);
		c2.r = (c3.r+c4.r)/2;

		//c2=(c2+gY)/2;
		//���ȵ���;
		return c0.x*c2;
	}


	//9����ģʽ��
	fat = -sin(c2.b/gY)*c0.y;
	c2.b = gY*(0.309724+fat)+(0.690276-fat)*c1.b;
	fat = sin(c2.g/gY)*c0.y;
	c2.g = gY*(1.59656+fat) - (0.245272+fat*0.245272/0.59656)*c1.r  - (0.351288+fat*0.351288/0.59656)*c1.b;
	fat = sin(c2.r/gY)*c0.y;
	c2.r = (1.26201+fat)*c1.r-(0.26201+fat)*gY;

	//���ȵ���;
	return c0.x*c2;
}

#endif

#endif
�      ��
 ��'    0	        #ifdef SHADER_MODEL // make safe to include in resource file to enforce dependency
#if SHADER_MODEL >= 0x400

Texture2D Texture;
SamplerState Sampler;

cbuffer cb0
{
	float4 BGColor;
};

struct PS_INPUT
{
	float4 p : SV_Position;
	float2 t : TEXCOORD0;
};

float4 ps_main0(PS_INPUT input) : SV_Target0
{
	float4 c = Texture.Sample(Sampler, input.t);
	c.a = min(c.a * 2, 1);
	return c;
}

float4 ps_main1(PS_INPUT input) : SV_Target0
{
	float4 c = Texture.Sample(Sampler, input.t);
	c.a = BGColor.a;
	return c;
}

#elif SHADER_MODEL <= 0x300

sampler Texture : register(s0);

float4 g_params[1];

#define BGColor	(g_params[0])

struct PS_INPUT
{
	float2 t : TEXCOORD0;
};

float4 ps_main0(PS_INPUT input) : COLOR
{
	float4 c = tex2D(Texture, input.t);
	// a = ;
	return c.bgra;
}

float4 ps_main1(PS_INPUT input) : COLOR
{
	float4 c = tex2D(Texture, input.t);
	c.a = BGColor.a;
	return c.bgra;
}

#endif
#endif
  NM      ��
 ��'    0	        #if defined(SHADER_MODEL) || defined(FXAA_GLSL_130)

#ifndef FXAA_GLSL_130
    #define FXAA_GLSL_130 0
#endif

#define UHQ_FXAA 1          //High Quality Fast Approximate Anti Aliasing. Adapted for GSdx from Timothy Lottes FXAA 3.11.
#define FxaaSubpixMax 0.0   //[0.00 to 1.00] Amount of subpixel aliasing removal. 0.00: Edge only antialiasing (no blurring)
#define FxaaEarlyExit 1     //[0 or 1] Use Fxaa early exit pathing. When disabled, the entire scene is antialiased(FSAA). 0 is off, 1 is on.

/*------------------------------------------------------------------------------
							 [GLOBALS|FUNCTIONS]
------------------------------------------------------------------------------*/
#if (FXAA_GLSL_130 == 1)

struct vertex_basic
{
    vec4 p;
    vec2 t;
};

#ifdef ENABLE_BINDLESS_TEX
layout(bindless_sampler, location = 0) uniform sampler2D TextureSampler;
#else
layout(binding = 0) uniform sampler2D TextureSampler;
#endif

in SHADER
{
    vec4 p;
    vec2 t;
} PSin;

layout(location = 0) out vec4 SV_Target0;

#else

#if (SHADER_MODEL >= 0x400)
Texture2D Texture : register(t0);
SamplerState TextureSampler : register(s0);
#else
texture2D Texture : register(t0);
sampler2D TextureSampler : register(s0);
#define SamplerState sampler2D
#endif

cbuffer cb0
{
	float4 _rcpFrame : register(c0);
};

struct VS_INPUT
{
	float4 p : POSITION;
	float2 t : TEXCOORD0;
};

struct VS_OUTPUT
{
	#if (SHADER_MODEL >= 0x400)
	float4 p : SV_Position;
	#else
	float4 p : TEXCOORD1;
	#endif
	float2 t : TEXCOORD0;
};

struct PS_OUTPUT
{
	#if (SHADER_MODEL >= 0x400)
	float4 c : SV_Target0;
	#else
	float4 c : COLOR0;
	#endif
};

#endif

/*------------------------------------------------------------------------------
                             [FXAA CODE SECTION]
------------------------------------------------------------------------------*/

#if (SHADER_MODEL >= 0x500)
#define FXAA_HLSL_5 1
#define FXAA_GATHER4_ALPHA 1
#elif (SHADER_MODEL >= 0x400)
#define FXAA_HLSL_4 1
#define FXAA_GATHER4_ALPHA 0
#elif (FXAA_GLSL_130 == 1)
#define FXAA_GATHER4_ALPHA 1
#else
#define FXAA_HLSL_3 1
#define FXAA_GATHER4_ALPHA 0
#endif

#if (FXAA_HLSL_5 == 1)
struct FxaaTex { SamplerState smpl; Texture2D tex; };
#define FxaaTexTop(t, p) t.tex.SampleLevel(t.smpl, p, 0.0)
#define FxaaTexOff(t, p, o, r) t.tex.SampleLevel(t.smpl, p, 0.0, o)
#define FxaaTexAlpha4(t, p) t.tex.GatherAlpha(t.smpl, p)
#define FxaaTexOffAlpha4(t, p, o) t.tex.GatherAlpha(t.smpl, p, o)
#define FxaaDiscard clip(-1)
#define FxaaSat(x) saturate(x)

#elif (FXAA_HLSL_4 == 1)
struct FxaaTex { SamplerState smpl; Texture2D tex; };
#define FxaaTexTop(t, p) t.tex.SampleLevel(t.smpl, p, 0.0)
#define FxaaTexOff(t, p, o, r) t.tex.SampleLevel(t.smpl, p, 0.0, o)
#define FxaaDiscard clip(-1)
#define FxaaSat(x) saturate(x)

#elif (FXAA_HLSL_3 == 1)
#define FxaaTex sampler2D
#define int2 float2
#define FxaaSat(x) saturate(x)
#define FxaaTexTop(t, p) tex2Dlod(t, float4(p, 0.0, 0.0))
#define FxaaTexOff(t, p, o, r) tex2Dlod(t, float4(p + (o * r), 0, 0))

#elif (FXAA_GLSL_130 == 1)

#define int2 ivec2
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define FxaaDiscard discard
#define FxaaSat(x) clamp(x, 0.0, 1.0)
#define FxaaTex sampler2D
#define FxaaTexTop(t, p) textureLod(t, p, 0.0)
#define FxaaTexOff(t, p, o, r) textureLodOffset(t, p, 0.0, o)
#if (FXAA_GATHER4_ALPHA == 1)
// use #extension GL_ARB_gpu_shader5 : enable
#define FxaaTexAlpha4(t, p) textureGather(t, p, 3)
#define FxaaTexOffAlpha4(t, p, o) textureGatherOffset(t, p, o, 3)
#endif

#endif

#define FxaaEdgeThreshold 0.063
#define FxaaEdgeThresholdMin 0.00
#define FXAA_QUALITY__P0 1.0
#define FXAA_QUALITY__P1 1.5
#define FXAA_QUALITY__P2 2.0
#define FXAA_QUALITY__P3 2.0
#define FXAA_QUALITY__P4 2.0
#define FXAA_QUALITY__P5 2.0
#define FXAA_QUALITY__P6 2.0
#define FXAA_QUALITY__P7 2.0
#define FXAA_QUALITY__P8 2.0
#define FXAA_QUALITY__P9 2.0
#define FXAA_QUALITY__P10 4.0
#define FXAA_QUALITY__P11 8.0
#define FXAA_QUALITY__P12 8.0

/*------------------------------------------------------------------------------
                        [GAMMA PREPASS CODE SECTION]
------------------------------------------------------------------------------*/
float RGBLuminance(float3 color)
{
	const float3 lumCoeff = float3(0.2126729, 0.7151522, 0.0721750);
	return dot(color.rgb, lumCoeff);
}

#if (FXAA_GLSL_130 == 0)
#define PixelSize float2(_rcpFrame.x, _rcpFrame.y)
#endif


float3 RGBGammaToLinear(float3 color, float gamma)
{
	color = FxaaSat(color);
	color.r = (color.r <= 0.0404482362771082) ?
	color.r / 12.92 : pow((color.r + 0.055) / 1.055, gamma);
	color.g = (color.g <= 0.0404482362771082) ?
	color.g / 12.92 : pow((color.g + 0.055) / 1.055, gamma);
	color.b = (color.b <= 0.0404482362771082) ?
	color.b / 12.92 : pow((color.b + 0.055) / 1.055, gamma);

	return color;
}

float3 LinearToRGBGamma(float3 color, float gamma)
{
	color = FxaaSat(color);
	color.r = (color.r <= 0.00313066844250063) ?
	color.r * 12.92 : 1.055 * pow(color.r, 1.0 / gamma) - 0.055;
	color.g = (color.g <= 0.00313066844250063) ?
	color.g * 12.92 : 1.055 * pow(color.g, 1.0 / gamma) - 0.055;
	color.b = (color.b <= 0.00313066844250063) ?
	color.b * 12.92 : 1.055 * pow(color.b, 1.0 / gamma) - 0.055;

	return color;
}

float4 PreGammaPass(float4 color, float2 uv0)
{
	#if (SHADER_MODEL >= 0x400)
		color = Texture.Sample(TextureSampler, uv0);
    #elif (FXAA_GLSL_130 == 1)
		color = texture(TextureSampler, uv0);
	#else
		color = tex2D(TextureSampler, uv0);
	#endif

	const float GammaConst = 2.233;
	color.rgb = RGBGammaToLinear(color.rgb, GammaConst);
	color.rgb = LinearToRGBGamma(color.rgb, GammaConst);
	color.a = RGBLuminance(color.rgb);

	return color;
}


/*------------------------------------------------------------------------------
                        [FXAA CODE SECTION]
------------------------------------------------------------------------------*/

float FxaaLuma(float4 rgba)
{ 
	rgba.w = RGBLuminance(rgba.xyz);
	return rgba.w; 
}

float4 FxaaPixelShader(float2 pos, FxaaTex tex, float2 fxaaRcpFrame, float fxaaSubpix, float fxaaEdgeThreshold, float fxaaEdgeThresholdMin)
{
	float2 posM;
	posM.x = pos.x;
	posM.y = pos.y;

	#if (FXAA_GATHER4_ALPHA == 1)
	float4 rgbyM = FxaaTexTop(tex, posM);
	float4 luma4A = FxaaTexAlpha4(tex, posM);
	float4 luma4B = FxaaTexOffAlpha4(tex, posM, int2(-1, -1));
	rgbyM.w = RGBLuminance(rgbyM.xyz);

	#define lumaM rgbyM.w
	#define lumaE luma4A.z
	#define lumaS luma4A.x
	#define lumaSE luma4A.y
	#define lumaNW luma4B.w
	#define lumaN luma4B.z
	#define lumaW luma4B.x
    
	#else
	float4 rgbyM = FxaaTexTop(tex, posM);
	rgbyM.w = RGBLuminance(rgbyM.xyz);
	#define lumaM rgbyM.w

	float lumaS = FxaaLuma(FxaaTexOff(tex, posM, int2( 0, 1), fxaaRcpFrame.xy));
	float lumaE = FxaaLuma(FxaaTexOff(tex, posM, int2( 1, 0), fxaaRcpFrame.xy));
	float lumaN = FxaaLuma(FxaaTexOff(tex, posM, int2( 0,-1), fxaaRcpFrame.xy));
	float lumaW = FxaaLuma(FxaaTexOff(tex, posM, int2(-1, 0), fxaaRcpFrame.xy));
	#endif

	float maxSM = max(lumaS, lumaM);
	float minSM = min(lumaS, lumaM);
	float maxESM = max(lumaE, maxSM);
	float minESM = min(lumaE, minSM);
	float maxWN = max(lumaN, lumaW);
	float minWN = min(lumaN, lumaW);

	float rangeMax = max(maxWN, maxESM);
	float rangeMin = min(minWN, minESM);
	float range = rangeMax - rangeMin;
	float rangeMaxScaled = rangeMax * fxaaEdgeThreshold;
	float rangeMaxClamped = max(fxaaEdgeThresholdMin, rangeMaxScaled);

	bool earlyExit = range < rangeMaxClamped;
	#if (FxaaEarlyExit == 1)
	if(earlyExit) { return rgbyM; }
	#endif

	#if (FXAA_GATHER4_ALPHA == 0)
	float lumaNW = FxaaLuma(FxaaTexOff(tex, posM, int2(-1,-1), fxaaRcpFrame.xy));
	float lumaSE = FxaaLuma(FxaaTexOff(tex, posM, int2( 1, 1), fxaaRcpFrame.xy));
	float lumaNE = FxaaLuma(FxaaTexOff(tex, posM, int2( 1,-1), fxaaRcpFrame.xy));
	float lumaSW = FxaaLuma(FxaaTexOff(tex, posM, int2(-1, 1), fxaaRcpFrame.xy));
	#else
	float lumaNE = FxaaLuma(FxaaTexOff(tex, posM, int2( 1,-1), fxaaRcpFrame.xy));
	float lumaSW = FxaaLuma(FxaaTexOff(tex, posM, int2(-1, 1), fxaaRcpFrame.xy));
	#endif

	float lumaNS = lumaN + lumaS;
	float lumaWE = lumaW + lumaE;
	float subpixRcpRange = 1.0/range;
	float subpixNSWE = lumaNS + lumaWE;
	float edgeHorz1 = (-2.0 * lumaM) + lumaNS;
	float edgeVert1 = (-2.0 * lumaM) + lumaWE;
	float lumaNESE = lumaNE + lumaSE;
	float lumaNWNE = lumaNW + lumaNE;
	float edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
	float edgeVert2 = (-2.0 * lumaN) + lumaNWNE;

	float lumaNWSW = lumaNW + lumaSW;
	float lumaSWSE = lumaSW + lumaSE;
	float edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
	float edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
	float edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
	float edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
	float edgeHorz = abs(edgeHorz3) + edgeHorz4;
	float edgeVert = abs(edgeVert3) + edgeVert4;

	float subpixNWSWNESE = lumaNWSW + lumaNESE;
	float lengthSign = fxaaRcpFrame.x;
	bool horzSpan = edgeHorz >= edgeVert;
	float subpixA = subpixNSWE * 2.0 + subpixNWSWNESE;
	if(!horzSpan) lumaN = lumaW;
	if(!horzSpan) lumaS = lumaE;
	if(horzSpan) lengthSign = fxaaRcpFrame.y;
	float subpixB = (subpixA * (1.0/12.0)) - lumaM;

	float gradientN = lumaN - lumaM;
	float gradientS = lumaS - lumaM;
	float lumaNN = lumaN + lumaM;
	float lumaSS = lumaS + lumaM;
	bool pairN = abs(gradientN) >= abs(gradientS);
	float gradient = max(abs(gradientN), abs(gradientS));
	if(pairN) lengthSign = -lengthSign;
	float subpixC = FxaaSat(abs(subpixB) * subpixRcpRange);

	float2 posB;
	posB.x = posM.x;
	posB.y = posM.y;
	float2 offNP;
	offNP.x = (!horzSpan) ? 0.0 : fxaaRcpFrame.x;
	offNP.y = ( horzSpan) ? 0.0 : fxaaRcpFrame.y;
	if(!horzSpan) posB.x += lengthSign * 0.5;
	if( horzSpan) posB.y += lengthSign * 0.5;

	float2 posN;
	posN.x = posB.x - offNP.x * FXAA_QUALITY__P0;
	posN.y = posB.y - offNP.y * FXAA_QUALITY__P0;
	float2 posP;
	posP.x = posB.x + offNP.x * FXAA_QUALITY__P0;
	posP.y = posB.y + offNP.y * FXAA_QUALITY__P0;
	float subpixD = ((-2.0)*subpixC) + 3.0;
	float lumaEndN = FxaaLuma(FxaaTexTop(tex, posN));
	float subpixE = subpixC * subpixC;
	float lumaEndP = FxaaLuma(FxaaTexTop(tex, posP));

	if(!pairN) lumaNN = lumaSS;
	float gradientScaled = gradient * 1.0/4.0;
	float lumaMM = lumaM - lumaNN * 0.5;
	float subpixF = subpixD * subpixE;
	bool lumaMLTZero = lumaMM < 0.0;
	lumaEndN -= lumaNN * 0.5;
	lumaEndP -= lumaNN * 0.5;
	bool doneN = abs(lumaEndN) >= gradientScaled;
	bool doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P1;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P1;
	bool doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P1;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P1;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P2;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P2;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P2;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P2;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P3;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P3;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P3;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P3;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P4;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P4;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P4;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P4;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P5;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P5;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P5;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P5;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P6;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P6;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P6;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P6;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P7;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P7;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P7;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P7;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P8;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P8;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P8;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P8;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P9;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P9;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P9;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P9;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P10;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P10;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P10;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P10;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P11;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P11;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P11;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P11;

	if(doneNP) {
	if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
	if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
	if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
	if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
	doneN = abs(lumaEndN) >= gradientScaled;
	doneP = abs(lumaEndP) >= gradientScaled;
	if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P12;
	if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P12;
	doneNP = (!doneN) || (!doneP);
	if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P12;
	if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P12;
	}}}}}}}}}}}

	float dstN = posM.x - posN.x;
	float dstP = posP.x - posM.x;
	if(!horzSpan) dstN = posM.y - posN.y;
	if(!horzSpan) dstP = posP.y - posM.y;

	bool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
	float spanLength = (dstP + dstN);
	bool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
	float spanLengthRcp = 1.0/spanLength;

	bool directionN = dstN < dstP;
	float dst = min(dstN, dstP);
	bool goodSpan = directionN ? goodSpanN : goodSpanP;
	float subpixG = subpixF * subpixF;
	float pixelOffset = (dst * (-spanLengthRcp)) + 0.5;
	float subpixH = subpixG * fxaaSubpix;

	float pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
	float pixelOffsetSubpix = max(pixelOffsetGood, subpixH);
	if(!horzSpan) posM.x += pixelOffsetSubpix * lengthSign;
	if( horzSpan) posM.y += pixelOffsetSubpix * lengthSign;

	return float4(FxaaTexTop(tex, posM).xyz, lumaM);
}

#if (FXAA_GLSL_130 == 1)
float4 FxaaPass(float4 FxaaColor, float2 uv0)
#else
float4 FxaaPass(float4 FxaaColor : COLOR0, float2 uv0 : TEXCOORD0)
#endif
{

	#if (SHADER_MODEL >= 0x400)
	FxaaTex tex;
	tex.tex = Texture;
	tex.smpl = TextureSampler;

	Texture.GetDimensions(PixelSize.x, PixelSize.y);
	FxaaColor = FxaaPixelShader(uv0, tex, 1.0/PixelSize.xy, FxaaSubpixMax, FxaaEdgeThreshold, FxaaEdgeThresholdMin);

    #elif (FXAA_GLSL_130 == 1)

	vec2 PixelSize = textureSize(TextureSampler, 0);
	FxaaColor = FxaaPixelShader(uv0, TextureSampler, 1.0/PixelSize.xy, FxaaSubpixMax, FxaaEdgeThreshold, FxaaEdgeThresholdMin);

	#else
	FxaaTex tex;
	tex = TextureSampler;
	FxaaColor = FxaaPixelShader(uv0, tex, PixelSize.xy, FxaaSubpixMax, FxaaEdgeThreshold, FxaaEdgeThresholdMin);
	#endif

	return FxaaColor;
}

/*------------------------------------------------------------------------------
                      [MAIN() & COMBINE PASS CODE SECTION]
------------------------------------------------------------------------------*/
#if (FXAA_GLSL_130 == 1)

void ps_main()
{
    vec4 color = texture(TextureSampler, PSin.t);
    color      = PreGammaPass(color, PSin.t);
    color      = FxaaPass(color, PSin.t);

    SV_Target0 = color;
}

#else

PS_OUTPUT ps_main(VS_OUTPUT input)
{
	PS_OUTPUT output;

	#if (SHADER_MODEL >= 0x400)
		float4 color = Texture.Sample(TextureSampler, input.t);

		color = PreGammaPass(color, input.t);
		color = FxaaPass(color, input.t);
	#else
		float4 color = tex2D(TextureSampler, input.t);

		color = PreGammaPass(color, input.t);
		color = FxaaPass(color, input.t);
	#endif

	output.c = color;
	
	return output;
}

#endif

#endif
  �      ��
 ��'    0	        #ifdef SHADER_MODEL // make safe to include in resource file to enforce dependency

#ifndef VS_TME
#define VS_TME 1
#define VS_FST 1
#endif

#ifndef GS_IIP
#define GS_IIP 0
#define GS_PRIM 2
#endif

#ifndef PS_BATCH_SIZE
#define PS_BATCH_SIZE 2048
#define PS_FPSM PSM_PSMCT32
#define PS_ZPSM PSM_PSMZ16
#endif

#define PSM_PSMCT32		0
#define PSM_PSMCT24		1
#define PSM_PSMCT16		2
#define PSM_PSMCT16S	10
#define PSM_PSMT8		19
#define PSM_PSMT4		20
#define PSM_PSMT8H		27
#define PSM_PSMT4HL		36
#define PSM_PSMT4HH		44
#define PSM_PSMZ32		48
#define PSM_PSMZ24		49
#define PSM_PSMZ16		50
#define PSM_PSMZ16S		58

struct VS_INPUT
{
	float2 st : TEXCOORD0;
	float4 c : COLOR0;
	float q : TEXCOORD1;
	uint2 p : POSITION0;
	uint z : POSITION1;
	uint2 uv : TEXCOORD2;
	float4 f : COLOR1;
};

struct VS_OUTPUT
{
	float4 p : SV_Position;
	float2 z : TEXCOORD0;
	float4 t : TEXCOORD1;
	float4 c : COLOR0;
};

struct GS_OUTPUT
{
	float4 p : SV_Position;
	float2 z : TEXCOORD0;
	float4 t : TEXCOORD1;
	float4 c : COLOR0;
	uint id : SV_PrimitiveID;
};

cbuffer VSConstantBuffer : register(c0)
{
	float4 VertexScale;
	float4 VertexOffset;
};

cbuffer PSConstantBuffer : register(c0)
{
	uint2 WriteMask;
};

struct FragmentLinkItem
{
	uint c, z, id, next;
};

RWByteAddressBuffer VideoMemory : register(u0);
RWStructuredBuffer<FragmentLinkItem> FragmentLinkBuffer : register(u1);
RWByteAddressBuffer StartOffsetBuffer : register(u2);
//RWTexture2D<uint> VideoMemory : register(u2); // 8192 * 512 R8_UINT

Buffer<int2> FZRowOffset : register(t0);
Buffer<int2> FZColOffset : register(t1);
Texture2D<float4> Palette : register(t2);
Texture2D<float4> Texture : register(t3);

VS_OUTPUT vs_main(VS_INPUT input)
{
	VS_OUTPUT output;

	output.p = float4(input.p, 0.0f, 0.0f) * VertexScale - VertexOffset;
	output.z = float2(input.z & 0xffff, input.z >> 16); // TODO: min(input.z, 0xffffff00) ?

	if(VS_TME)
	{
		if(VS_FST)
		{
			output.t.xy = input.uv;
			output.t.w = 1.0f;
		}
		else
		{
			output.t.xy = input.st;
			output.t.w = input.q;
		}
	}
	else
	{
		output.t.xy = 0;
		output.t.w = 1.0f;
	}

	output.c = input.c;
	output.t.z = input.f.r;

	return output;
}

#if GS_PRIM == 0

[maxvertexcount(1)]
void gs_main(point VS_OUTPUT input[1], inout PointStream<GS_OUTPUT> stream, uint id : SV_PrimitiveID)
{
	GS_OUTPUT output;

	output.p = input[0].p;
	output.z = input[0].z;
	output.t = input[0].t;
	output.c = input[0].c;
	output.id = id;

	stream.Append(output);
}

#elif GS_PRIM == 1

[maxvertexcount(2)]
void gs_main(line VS_OUTPUT input[2], inout LineStream<GS_OUTPUT> stream, uint id : SV_PrimitiveID)
{
	[unroll]
	for(int i = 0; i < 2; i++)
	{
		GS_OUTPUT output;

		output.p = input[i].p;
		output.z = input[i].z;
		output.t = input[i].t;
		output.c = input[i].c;
		output.id = id;

#if GS_IIP == 0
		if(i != 1) output.c = input[1].c;
#endif

		stream.Append(output);
	}
}

#elif GS_PRIM == 2

[maxvertexcount(3)]
void gs_main(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> stream, uint id : SV_PrimitiveID)
{
	[unroll]
	for(int i = 0; i < 3; i++)
	{
		GS_OUTPUT output;

		output.p = input[i].p;
		output.z = input[i].z;
		output.t = input[i].t;
		output.c = input[i].c;
		output.id = id;

#if GS_IIP == 0
		if(i != 2) output.c = input[2].c;
#endif

		stream.Append(output);
	}
}

#elif GS_PRIM == 3

[maxvertexcount(4)]
void gs_main(line VS_OUTPUT input[2], inout TriangleStream<GS_OUTPUT> stream, uint id : SV_PrimitiveID)
{
	GS_OUTPUT lt, rb, lb, rt;

	lt.p = input[0].p;
	lt.z = input[1].z;
	lt.t.xy = input[0].t.xy;
	lt.t.zw = input[1].t.zw;
	lt.c = input[0].c;
	lt.id = id;

#if GS_IIP == 0
	lt.c = input[1].c;
#endif

	rb.p = input[1].p;
	rb.z = input[1].z;
	rb.t = input[1].t;
	rb.c = input[1].c;
	rb.id = id;

	lb = lt;	
	lb.p.y = rb.p.y;
	lb.t.y = rb.t.y;

	rt = rb;	
	rt.p.y = lt.p.y;
	rt.t.y = lt.t.y;

	stream.Append(lt);
	stream.Append(lb);
	stream.Append(rt);
	stream.Append(rb);
}

#endif

uint CompressColor32(float4 f)
{
	uint4 c = (uint4)(f * 0xff) << uint4(0, 8, 16, 24);

	return c.r | c.g | c.b | c.a;
}

uint DecompressColor16(uint c)
{
	uint r = (c & 0x001f) << 3;
	uint g = (c & 0x03e0) << 6;
	uint b = (c & 0x7c00) << 9;
	uint a = (c & 0x8000) << 15;

	return r | g | b | a;
}

uint ReadPixel(uint addr)
{
	return VideoMemory.Load(addr) >> ((addr & 2) << 3);
}

void WritePixel(uint addr, uint value, uint psm)
{
	uint tmp;

	switch(psm)
	{
	case PSM_PSMCT32:
	case PSM_PSMZ32:
	case PSM_PSMCT24:
	case PSM_PSMZ24:
		VideoMemory.Store(addr, value);
		break;
	case PSM_PSMCT16:
	case PSM_PSMCT16S:
	case PSM_PSMZ16:
	case PSM_PSMZ16S:
		tmp = (addr & 2) << 3;
		value = ((value << tmp) ^ VideoMemory.Load(addr)) & (0x0000ffff << tmp);
		VideoMemory.InterlockedXor(addr, value, tmp);
		break;
	}
}

void ps_main0(GS_OUTPUT input)
{
	uint x = (uint)input.p.x;
	uint y = (uint)input.p.y;

	uint tail = FragmentLinkBuffer.IncrementCounter();

	uint index = (y << 11) + x;
	uint next = 0;

	StartOffsetBuffer.InterlockedExchange(index * 4, tail, next);

	FragmentLinkItem item;

	// TODO: preprocess color (tfx, alpha test), z-test

	item.c = CompressColor32(input.c);
	item.z = (uint)(input.z.y * 0x10000 + input.z.x);
	item.id = input.id;
	item.next = next;

	FragmentLinkBuffer[tail] = item;
}

void ps_main1(GS_OUTPUT input)
{
	uint2 pos = (uint2)input.p.xy;

	// sort fragments

	uint StartOffsetIndex = (pos.y << 11) + pos.x;

	int index[PS_BATCH_SIZE];
	int count = 0;

	uint next = StartOffsetBuffer.Load(StartOffsetIndex * 4);

	StartOffsetBuffer.Store(StartOffsetIndex * 4, 0);

	[allow_uav_condition]
	while(next != 0)
	{
		index[count++] = next;

		next = FragmentLinkBuffer[next].next;
	}

	int N2 = 1 << (int)(ceil(log2(count)));

	[allow_uav_condition]
	for(int i = count; i < N2; i++)
	{
		index[i] = 0;
	}

	[allow_uav_condition]
	for(int k = 2; k <= N2; k = 2 * k)
	{
		[allow_uav_condition]
		for(int j = k >> 1; j > 0 ; j = j >> 1) 
		{
			[allow_uav_condition]
			for(int i = 0; i < N2; i++) 
			{
				uint i_id = FragmentLinkBuffer[index[i]].id;

				int ixj = i ^ j;

				if(ixj > i)
				{
					uint ixj_id = FragmentLinkBuffer[index[ixj]].id;

					if((i & k) == 0 && i_id > ixj_id)
					{ 
						int temp = index[i];
						index[i] = index[ixj];
						index[ixj] = temp;
					}

					if((i & k) != 0 && i_id < ixj_id)
					{
						int temp = index[i];
						index[i] = index[ixj];
						index[ixj] = temp;
					}
				}
			}
		}
	}

	uint2 addr = (uint2)(FZRowOffset[pos.y] + FZColOffset[pos.x]) << 1;

	uint dc = ReadPixel(addr.x);
	uint dz = ReadPixel(addr.y);

	uint sc = dc;
	uint sz = dz;

	[allow_uav_condition]
	while(--count >= 0)
	{
		FragmentLinkItem f = FragmentLinkBuffer[index[count]];

		// TODO

		if(sz < f.z)
		{
			sc = f.c;
			sz = f.z;
		}
	}

	uint c = sc; // (dc & ~WriteMask.x) | (sc & WriteMask.x);
	uint z = 0;//sz; //(dz & ~WriteMask.y) | (sz & WriteMask.y);

	WritePixel(addr.x, c, PS_FPSM);
	WritePixel(addr.y, z, PS_ZPSM);
}

#endif
�      ��
 ��'    0	        #ifdef SHADER_MODEL // make safe to include in resource file to enforce dependency

/*
** Contrast, saturation, brightness
** Code of this function is from TGM's shader pack
** http://irrlicht.sourceforge.net/phpBB2/viewtopic.php?t=21057
*/

// For all settings: 1.0 = 100% 0.5=50% 1.5 = 150% 
float4 ContrastSaturationBrightness(float4 color) // Ported to HLSL
{
	const float sat = SB_SATURATION / 50.0;
	const float brt = SB_BRIGHTNESS / 50.0;
	const float con = SB_CONTRAST / 50.0;
	
	// Increase or decrease these values to adjust r, g and b color channels separately
	const float AvgLumR = 0.5;
	const float AvgLumG = 0.5;
	const float AvgLumB = 0.5;
	
	const float3 LumCoeff = float3(0.2125, 0.7154, 0.0721);
	
	float3 AvgLumin = float3(AvgLumR, AvgLumG, AvgLumB);
	float3 brtColor = color.rgb * brt;
	float3 intensity = dot(brtColor, LumCoeff);
	float3 satColor = lerp(intensity, brtColor, sat);
	float3 conColor = lerp(AvgLumin, satColor, con);

	color.rgb = conColor;	
	return color;
}

#if SHADER_MODEL >= 0x400

Texture2D Texture;
SamplerState Sampler;

cbuffer cb0
{
	float4 BGColor;
};

struct PS_INPUT
{
	float4 p : SV_Position;
	float2 t : TEXCOORD0;
};

float4 ps_main(PS_INPUT input) : SV_Target0
{
	float4 c = Texture.Sample(Sampler, input.t);
	return ContrastSaturationBrightness(c);
}


#elif SHADER_MODEL <= 0x300

sampler Texture : register(s0);

float4 g_params[1];

#define BGColor	(g_params[0])

struct PS_INPUT
{
	float2 t : TEXCOORD0;
};

float4 ps_main(PS_INPUT input) : COLOR
{
	float4 c = tex2D(Texture, input.t);
	return ContrastSaturationBrightness(c);
}

#endif
#endif
  C�      ��
 ��'    0	        #if defined(CL_VERSION_1_1) || defined(CL_VERSION_1_2) // make safe to include in resource file to enforce dependency

#ifdef cl_amd_printf
#pragma OPENCL EXTENSION cl_amd_printf : enable
#endif

#ifdef cl_amd_media_ops
#pragma OPENCL EXTENSION cl_amd_media_ops : enable
#else
#endif

#ifdef cl_amd_media_ops2
#pragma OPENCL EXTENSION cl_amd_media_ops2 : enable
#else
#endif

#ifndef CL_FLT_EPSILON
#define CL_FLT_EPSILON 1.1920928955078125e-7f
#endif

#if MAX_PRIM_PER_BATCH == 64u
	#define BIN_TYPE ulong
#elif MAX_PRIM_PER_BATCH == 32u
	#define BIN_TYPE uint
#else
	#error "MAX_PRIM_PER_BATCH != 32u OR 64u"
#endif

typedef struct
{
	union {float4 p; struct {float x, y; uint z, f;};};
	union {float4 tc; struct {float s, t, q; uchar4 c;};};
} gs_vertex;

typedef struct
{
	gs_vertex v[3];
	uint zmin;
	uint pb_index;
	uint _pad[2];
} gs_prim;

typedef struct
{
	float4 dx, dy;
	float4 zero;
	float4 reject_corner;
} gs_barycentric;

typedef struct
{
	struct {uint first, last;} bounds[MAX_BIN_PER_BATCH];
	BIN_TYPE bin[MAX_BIN_COUNT];
	uchar4 bbox[MAX_PRIM_COUNT];
	gs_prim prim[MAX_PRIM_COUNT];
	gs_barycentric barycentric[MAX_PRIM_COUNT];
} gs_env;

typedef struct
{
	int4 scissor;
	char dimx[4][4];
	int fbp, zbp, bw;
	uint fm, zm;
	uchar4 fog; // rgb
	uchar aref, afix;
	uchar ta0, ta1;
	int tbp[7], tbw[7];
	int minu, maxu, minv, maxv;
	int lod; // lcm == 1
	int mxl;
	float l; // TEX1.L * -0x10000
	float k; // TEX1.K * 0x10000
	uchar4 clut[256]; // TODO: this could be an index to a separate buffer, it may be the same across several gs_params following eachother
} gs_param;

enum GS_PRIM_CLASS
{
	GS_POINT_CLASS,
	GS_LINE_CLASS,
	GS_TRIANGLE_CLASS,
	GS_SPRITE_CLASS
};

enum GS_PSM
{
	PSM_PSMCT32,
	PSM_PSMCT24,
	PSM_PSMCT16,
	PSM_PSMCT16S,
	PSM_PSMZ32,
	PSM_PSMZ24,
	PSM_PSMZ16,
	PSM_PSMZ16S,
	PSM_PSMT8,
	PSM_PSMT4,
	PSM_PSMT8H,
	PSM_PSMT4HL,
	PSM_PSMT4HH,
};

enum GS_TFX
{
	TFX_MODULATE	= 0,
	TFX_DECAL		= 1,
	TFX_HIGHLIGHT	= 2,
	TFX_HIGHLIGHT2	= 3,
	TFX_NONE		= 4,
};

enum GS_CLAMP
{
	CLAMP_REPEAT		= 0,
	CLAMP_CLAMP			= 1,
	CLAMP_REGION_CLAMP	= 2,
	CLAMP_REGION_REPEAT	= 3,
};

enum GS_ZTST
{
	ZTST_NEVER		= 0,
	ZTST_ALWAYS		= 1,
	ZTST_GEQUAL		= 2,
	ZTST_GREATER	= 3,
};

enum GS_ATST
{
	ATST_NEVER		= 0,
	ATST_ALWAYS		= 1,
	ATST_LESS		= 2,
	ATST_LEQUAL		= 3,
	ATST_EQUAL		= 4,
	ATST_GEQUAL		= 5,
	ATST_GREATER	= 6,
	ATST_NOTEQUAL	= 7,
};

enum GS_AFAIL
{
	AFAIL_KEEP		= 0,
	AFAIL_FB_ONLY	= 1,
	AFAIL_ZB_ONLY	= 2,
	AFAIL_RGB_ONLY	= 3,
};

__constant uchar blockTable32[4][8] =
{
	{  0,  1,  4,  5, 16, 17, 20, 21},
	{  2,  3,  6,  7, 18, 19, 22, 23},
	{  8,  9, 12, 13, 24, 25, 28, 29},
	{ 10, 11, 14, 15, 26, 27, 30, 31}
};

__constant uchar blockTable32Z[4][8] =
{
	{ 24, 25, 28, 29,  8,  9, 12, 13},
	{ 26, 27, 30, 31, 10, 11, 14, 15},
	{ 16, 17, 20, 21,  0,  1,  4,  5},
	{ 18, 19, 22, 23,  2,  3,  6,  7}
};

__constant uchar blockTable16[8][4] =
{
	{  0,  2,  8, 10 },
	{  1,  3,  9, 11 },
	{  4,  6, 12, 14 },
	{  5,  7, 13, 15 },
	{ 16, 18, 24, 26 },
	{ 17, 19, 25, 27 },
	{ 20, 22, 28, 30 },
	{ 21, 23, 29, 31 }
};

__constant uchar blockTable16S[8][4] =
{
	{  0,  2, 16, 18 },
	{  1,  3, 17, 19 },
	{  8, 10, 24, 26 },
	{  9, 11, 25, 27 },
	{  4,  6, 20, 22 },
	{  5,  7, 21, 23 },
	{ 12, 14, 28, 30 },
	{ 13, 15, 29, 31 }
};

__constant uchar blockTable16Z[8][4] =
{
	{ 24, 26, 16, 18 },
	{ 25, 27, 17, 19 },
	{ 28, 30, 20, 22 },
	{ 29, 31, 21, 23 },
	{  8, 10,  0,  2 },
	{  9, 11,  1,  3 },
	{ 12, 14,  4,  6 },
	{ 13, 15,  5,  7 }
};

__constant uchar blockTable16SZ[8][4] =
{
	{ 24, 26,  8, 10 },
	{ 25, 27,  9, 11 },
	{ 16, 18,  0,  2 },
	{ 17, 19,  1,  3 },
	{ 28, 30, 12, 14 },
	{ 29, 31, 13, 15 },
	{ 20, 22,  4,  6 },
	{ 21, 23,  5,  7 }
};

__constant uchar blockTable8[4][8] =
{
	{  0,  1,  4,  5, 16, 17, 20, 21},
	{  2,  3,  6,  7, 18, 19, 22, 23},
	{  8,  9, 12, 13, 24, 25, 28, 29},
	{ 10, 11, 14, 15, 26, 27, 30, 31}
};

__constant uchar blockTable4[8][4] =
{
	{  0,  2,  8, 10 },
	{  1,  3,  9, 11 },
	{  4,  6, 12, 14 },
	{  5,  7, 13, 15 },
	{ 16, 18, 24, 26 },
	{ 17, 19, 25, 27 },
	{ 20, 22, 28, 30 },
	{ 21, 23, 29, 31 }
};

__constant uchar columnTable32[8][8] =
{
	{  0,  1,  4,  5,  8,  9, 12, 13 },
	{  2,  3,  6,  7, 10, 11, 14, 15 },
	{ 16, 17, 20, 21, 24, 25, 28, 29 },
	{ 18, 19, 22, 23, 26, 27, 30, 31 },
	{ 32, 33, 36, 37, 40, 41, 44, 45 },
	{ 34, 35, 38, 39, 42, 43, 46, 47 },
	{ 48, 49, 52, 53, 56, 57, 60, 61 },
	{ 50, 51, 54, 55, 58, 59, 62, 63 },
};

__constant uchar columnTable16[8][16] =
{
	{   0,   2,   8,  10,  16,  18,  24,  26,
	    1,   3,   9,  11,  17,  19,  25,  27 },
	{   4,   6,  12,  14,  20,  22,  28,  30,
	    5,   7,  13,  15,  21,  23,  29,  31 },
	{  32,  34,  40,  42,  48,  50,  56,  58,
	   33,  35,  41,  43,  49,  51,  57,  59 },
	{  36,  38,  44,  46,  52,  54,  60,  62,
	   37,  39,  45,  47,  53,  55,  61,  63 },
	{  64,  66,  72,  74,  80,  82,  88,  90,
	   65,  67,  73,  75,  81,  83,  89,  91 },
	{  68,  70,  76,  78,  84,  86,  92,  94,
	   69,  71,  77,  79,  85,  87,  93,  95 },
	{  96,  98, 104, 106, 112, 114, 120, 122,
	   97,  99, 105, 107, 113, 115, 121, 123 },
	{ 100, 102, 108, 110, 116, 118, 124, 126,
	  101, 103, 109, 111, 117, 119, 125, 127 },
};

__constant uchar columnTable8[16][16] =
{
	{   0,   4,  16,  20,  32,  36,  48,  52,	// column 0
	    2,   6,  18,  22,  34,  38,  50,  54 },
	{   8,  12,  24,  28,  40,  44,  56,  60,
	   10,  14,  26,  30,  42,  46,  58,  62 },
	{  33,  37,  49,  53,   1,   5,  17,  21,
	   35,  39,  51,  55,   3,   7,  19,  23 },
	{  41,  45,  57,  61,   9,  13,  25,  29,
	   43,  47,  59,  63,  11,  15,  27,  31 },
	{  96, 100, 112, 116,  64,  68,  80,  84, 	// column 1
	   98, 102, 114, 118,  66,  70,  82,  86 },
	{ 104, 108, 120, 124,  72,  76,  88,  92,
	  106, 110, 122, 126,  74,  78,  90,  94 },
	{  65,  69,  81,  85,  97, 101, 113, 117,
	   67,  71,  83,  87,  99, 103, 115, 119 },
	{  73,  77,  89,  93, 105, 109, 121, 125,
	   75,  79,  91,  95, 107, 111, 123, 127 },
	{ 128, 132, 144, 148, 160, 164, 176, 180,	// column 2
	  130, 134, 146, 150, 162, 166, 178, 182 },
	{ 136, 140, 152, 156, 168, 172, 184, 188,
	  138, 142, 154, 158, 170, 174, 186, 190 },
	{ 161, 165, 177, 181, 129, 133, 145, 149,
	  163, 167, 179, 183, 131, 135, 147, 151 },
	{ 169, 173, 185, 189, 137, 141, 153, 157,
	  171, 175, 187, 191, 139, 143, 155, 159 },
	{ 224, 228, 240, 244, 192, 196, 208, 212,	// column 3
	  226, 230, 242, 246, 194, 198, 210, 214 },
	{ 232, 236, 248, 252, 200, 204, 216, 220,
	  234, 238, 250, 254, 202, 206, 218, 222 },
	{ 193, 197, 209, 213, 225, 229, 241, 245,
	  195, 199, 211, 215, 227, 231, 243, 247 },
	{ 201, 205, 217, 221, 233, 237, 249, 253,
	  203, 207, 219, 223, 235, 239, 251, 255 },
};

__constant ushort columnTable4[16][32] =
{
	{   0,   8,  32,  40,  64,  72,  96, 104,	// column 0
	    2,  10,  34,  42,  66,  74,  98, 106,
	    4,  12,  36,  44,  68,  76, 100, 108,
	    6,  14,  38,  46,  70,  78, 102, 110 },
	{  16,  24,  48,  56,  80,  88, 112, 120,
	   18,  26,  50,  58,  82,  90, 114, 122,
	   20,  28,  52,  60,  84,  92, 116, 124,
	   22,  30,  54,  62,  86,  94, 118, 126 },
	{  65,  73,  97, 105,   1,   9,  33,  41,
	   67,  75,  99, 107,   3,  11,  35,  43,
	   69,  77, 101, 109,   5,  13,  37,  45,
	   71,  79, 103, 111,   7,  15,  39,  47 },
	{  81,  89, 113, 121,  17,  25,  49,  57,
	   83,  91, 115, 123,  19,  27,  51,  59,
	   85,  93, 117, 125,  21,  29,  53,  61,
	   87,  95, 119, 127,  23,  31,  55,  63 },
	{ 192, 200, 224, 232, 128, 136, 160, 168,	// column 1
	  194, 202, 226, 234, 130, 138, 162, 170,
	  196, 204, 228, 236, 132, 140, 164, 172,
	  198, 206, 230, 238, 134, 142, 166, 174 },
	{ 208, 216, 240, 248, 144, 152, 176, 184,
	  210, 218, 242, 250, 146, 154, 178, 186,
	  212, 220, 244, 252, 148, 156, 180, 188,
	  214, 222, 246, 254, 150, 158, 182, 190 },
	{ 129, 137, 161, 169, 193, 201, 225, 233,
	  131, 139, 163, 171, 195, 203, 227, 235,
	  133, 141, 165, 173, 197, 205, 229, 237,
	  135, 143, 167, 175, 199, 207, 231, 239 },
	{ 145, 153, 177, 185, 209, 217, 241, 249,
	  147, 155, 179, 187, 211, 219, 243, 251,
	  149, 157, 181, 189, 213, 221, 245, 253,
	  151, 159, 183, 191, 215, 223, 247, 255 },
	{ 256, 264, 288, 296, 320, 328, 352, 360,	// column 2
	  258, 266, 290, 298, 322, 330, 354, 362,
	  260, 268, 292, 300, 324, 332, 356, 364,
	  262, 270, 294, 302, 326, 334, 358, 366 },
	{ 272, 280, 304, 312, 336, 344, 368, 376,
	  274, 282, 306, 314, 338, 346, 370, 378,
	  276, 284, 308, 316, 340, 348, 372, 380,
	  278, 286, 310, 318, 342, 350, 374, 382 },
	{ 321, 329, 353, 361, 257, 265, 289, 297,
	  323, 331, 355, 363, 259, 267, 291, 299,
	  325, 333, 357, 365, 261, 269, 293, 301,
	  327, 335, 359, 367, 263, 271, 295, 303 },
	{ 337, 345, 369, 377, 273, 281, 305, 313,
	  339, 347, 371, 379, 275, 283, 307, 315,
	  341, 349, 373, 381, 277, 285, 309, 317,
	  343, 351, 375, 383, 279, 287, 311, 319 },
	{ 448, 456, 480, 488, 384, 392, 416, 424,	// column 3
	  450, 458, 482, 490, 386, 394, 418, 426,
	  452, 460, 484, 492, 388, 396, 420, 428,
	  454, 462, 486, 494, 390, 398, 422, 430 },
	{ 464, 472, 496, 504, 400, 408, 432, 440,
	  466, 474, 498, 506, 402, 410, 434, 442,
	  468, 476, 500, 508, 404, 412, 436, 444,
	  470, 478, 502, 510, 406, 414, 438, 446 },
	{ 385, 393, 417, 425, 449, 457, 481, 489,
	  387, 395, 419, 427, 451, 459, 483, 491,
	  389, 397, 421, 429, 453, 461, 485, 493,
	  391, 399, 423, 431, 455, 463, 487, 495 },
	{ 401, 409, 433, 441, 465, 473, 497, 505,
	  403, 411, 435, 443, 467, 475, 499, 507,
	  405, 413, 437, 445, 469, 477, 501, 509,
	  407, 415, 439, 447, 471, 479, 503, 511 },
};

int BlockNumber32(int x, int y, int bp, int bw)
{
	return bp + mad24(y & ~0x1f, bw, (x >> 1) & ~0x1f) + blockTable32[(y >> 3) & 3][(x >> 3) & 7];
}

int BlockNumber16(int x, int y, int bp, int bw)
{
	return bp + mad24((y >> 1) & ~0x1f, bw, (x >> 1) & ~0x1f) + blockTable16[(y >> 3) & 7][(x >> 4) & 3];
}

int BlockNumber16S(int x, int y, int bp, int bw)
{
	return bp + mad24((y >> 1) & ~0x1f, bw, (x >> 1) & ~0x1f) + blockTable16S[(y >> 3) & 7][(x >> 4) & 3];
}

int BlockNumber32Z(int x, int y, int bp, int bw)
{
	return bp + mad24(y & ~0x1f, bw, (x >> 1) & ~0x1f) + blockTable32Z[(y >> 3) & 3][(x >> 3) & 7];
}

int BlockNumber16Z(int x, int y, int bp, int bw)
{
	return bp + mad24((y >> 1) & ~0x1f, bw, (x >> 1) & ~0x1f) + blockTable16Z[(y >> 3) & 7][(x >> 4) & 3];
}

int BlockNumber16SZ(int x, int y, int bp, int bw)
{
	return bp + mad24((y >> 1) & ~0x1f, bw, (x >> 1) & ~0x1f) + blockTable16SZ[(y >> 3) & 7][(x >> 4) & 3];
}

int BlockNumber8(int x, int y, int bp, int bw)
{
	return bp + mad24((y >> 1) & ~0x1f, bw >> 1, (x >> 2) & ~0x1f) + blockTable8[(y >> 4) & 3][(x >> 4) & 7];
}

int BlockNumber4(int x, int y, int bp, int bw)
{
	return bp + mad24((y >> 2) & ~0x1f, bw >> 1, (x >> 2) & ~0x1f) + blockTable4[(y >> 4) & 7][(x >> 5) & 3];
}

int PixelAddress32(int x, int y, int bp, int bw)
{
	return (BlockNumber32(x, y, bp, bw) << 6) + columnTable32[y & 7][x & 7];
}

int PixelAddress16(int x, int y, int bp, int bw)
{
	return (BlockNumber16(x, y, bp, bw) << 7) + columnTable16[y & 7][x & 15];
}

int PixelAddress16S(int x, int y, int bp, int bw)
{
	return (BlockNumber16S(x, y, bp, bw) << 7) + columnTable16[y & 7][x & 15];
}

int PixelAddress32Z(int x, int y, int bp, int bw)
{
	return (BlockNumber32Z(x, y, bp, bw) << 6) + columnTable32[y & 7][x & 7];
}

int PixelAddress16Z(int x, int y, int bp, int bw)
{
	return (BlockNumber16Z(x, y, bp, bw) << 7) + columnTable16[y & 7][x & 15];
}

int PixelAddress16SZ(int x, int y, int bp, int bw)
{
	return (BlockNumber16SZ(x, y, bp, bw) << 7) + columnTable16[y & 7][x & 15];
}

int PixelAddress8(int x, int y, int bp, int bw)
{
	return (BlockNumber8(x, y, bp, bw) << 8) + columnTable8[y & 15][x & 15];
}

int PixelAddress4(int x, int y, int bp, int bw)
{
	return (BlockNumber4(x, y, bp, bw) << 9) + columnTable4[y & 15][x & 31];
}

int PixelAddress(int x, int y, int bp, int bw, int psm)
{
	switch(psm)
	{
	default:
	case PSM_PSMCT32: 
	case PSM_PSMCT24: 
	case PSM_PSMT8H:
	case PSM_PSMT4HL:
	case PSM_PSMT4HH:
		return PixelAddress32(x, y, bp, bw);
	case PSM_PSMCT16: 
		return PixelAddress16(x, y, bp, bw);
	case PSM_PSMCT16S: 
		return PixelAddress16S(x, y, bp, bw);
	case PSM_PSMZ32: 
	case PSM_PSMZ24: 
		return PixelAddress32Z(x, y, bp, bw);
	case PSM_PSMZ16: 
		return PixelAddress16Z(x, y, bp, bw);
	case PSM_PSMZ16S: 
		return PixelAddress16SZ(x, y, bp, bw);
	case PSM_PSMT8:
		return PixelAddress8(x, y, bp, bw);
	case PSM_PSMT4:
		return PixelAddress4(x, y, bp, bw);
	}
}

uint ReadFrame(__global uchar* vm, int addr, int psm)
{
	switch(psm)
	{
	default:
	case PSM_PSMCT32: 
	case PSM_PSMCT24: 
	case PSM_PSMZ32: 
	case PSM_PSMZ24: 
		return ((__global uint*)vm)[addr];
	case PSM_PSMCT16: 
	case PSM_PSMCT16S: 
	case PSM_PSMZ16: 
	case PSM_PSMZ16S: 
		return ((__global ushort*)vm)[addr];
	}
}

void WriteFrame(__global uchar* vm, int addr, int psm, uint value)
{
	switch(psm)
	{
	default:
	case PSM_PSMCT32: 
	case PSM_PSMZ32:
	case PSM_PSMCT24: 
	case PSM_PSMZ24: 
		((__global uint*)vm)[addr] = value; 
		break;
	case PSM_PSMCT16: 
	case PSM_PSMCT16S: 
	case PSM_PSMZ16: 
	case PSM_PSMZ16S: 
		((__global ushort*)vm)[addr] = (ushort)value;
		break;
	}
}

bool is16bit(int psm)
{
	return psm < 8 && (psm & 3) >= 2;
}

bool is24bit(int psm)
{
	return psm < 8 && (psm & 3) == 1;
}

bool is32bit(int psm)
{
	return psm < 8 && (psm & 3) == 0;
}

#ifdef PRIM

int GetVertexPerPrim(int prim_class)
{
	switch(prim_class)
	{
	default:
	case GS_POINT_CLASS: return 1;
	case GS_LINE_CLASS: return 2;
	case GS_TRIANGLE_CLASS: return 3;
	case GS_SPRITE_CLASS: return 2;
	}
}

#define VERTEX_PER_PRIM GetVertexPerPrim(PRIM)

#endif

#ifdef KERNEL_PRIM

__kernel void KERNEL_PRIM(
	__global gs_env* env,
	__global uchar* vb_base, 
	__global uchar* ib_base,
	__global uchar* pb_base, 
	uint vb_start,
	uint ib_start,
	uint pb_start)
{
	size_t prim_index = get_global_id(0);

	__global gs_vertex* vb = (__global gs_vertex*)(vb_base + vb_start);
	__global uint* ib = (__global uint*)(ib_base + ib_start);
	__global gs_prim* prim = &env->prim[prim_index];
	
	ib += prim_index * VERTEX_PER_PRIM;

	uint pb_index = ib[0] >> 24;

	prim->pb_index = pb_index;

	__global gs_param* pb = (__global gs_param*)(pb_base + pb_start + pb_index * TFX_PARAM_SIZE);

	__global gs_vertex* v0 = &vb[ib[0] & 0x00ffffff];
	__global gs_vertex* v1 = &vb[ib[1] & 0x00ffffff];
	__global gs_vertex* v2 = &vb[ib[2] & 0x00ffffff];

	int2 pmin, pmax;

	if(PRIM == GS_POINT_CLASS)
	{
		pmin = pmax = convert_int2_rte(v0->p.xy);

		prim->v[0].p = v0->p;
		prim->v[0].tc = v0->tc;
	}
	else if(PRIM == GS_LINE_CLASS)
	{
		int2 p0 = convert_int2_rte(v0->p.xy);
		int2 p1 = convert_int2_rte(v1->p.xy);

		pmin = min(p0, p1);
		pmax = max(p0, p1);
	}
	else if(PRIM == GS_TRIANGLE_CLASS)
	{
		int2 p0 = convert_int2_rtp(v0->p.xy);
		int2 p1 = convert_int2_rtp(v1->p.xy);
		int2 p2 = convert_int2_rtp(v2->p.xy);

		pmin = min(min(p0, p1), p2);
		pmax = max(max(p0, p1), p2);

		// z needs special care, since it's a 32 bit unit, float cannot encode it exactly
		// only interpolate the relative to zmin and hopefully small values

		uint zmin = min(min(v0->z, v1->z), v2->z);
		
		prim->v[0].p = (float4)(v0->p.x, v0->p.y, as_float(v0->z - zmin), v0->p.w);
		prim->v[0].tc = v0->tc;
		prim->v[1].p = (float4)(v1->p.x, v1->p.y, as_float(v1->z - zmin), v1->p.w);
		prim->v[1].tc = v1->tc;
		prim->v[2].p = (float4)(v2->p.x, v2->p.y, as_float(v2->z - zmin), v2->p.w);
		prim->v[2].tc = v2->tc;

		prim->zmin = zmin;

		float4 dp0 = v1->p - v0->p;
		float4 dp1 = v0->p - v2->p;
		float4 dp2 = v2->p - v1->p;

		float cp = dp0.x * dp1.y - dp0.y * dp1.x;

		if(cp != 0.0f)
		{
			cp = native_recip(cp);

			float2 u = dp0.xy * cp;
			float2 v = -dp1.xy * cp;

			// v0 has the (0, 0, 1) barycentric coord, v1: (0, 1, 0), v2: (1, 0, 0)

			gs_barycentric b;

			b.dx = (float4)(-v.y, u.y, v.y - u.y, v0->p.x);
			b.dy = (float4)(v.x, -u.x, u.x - v.x, v0->p.y);

			dp0.xy = dp0.xy * sign(cp);
			dp1.xy = dp1.xy * sign(cp);
			dp2.xy = dp2.xy * sign(cp);

			b.zero.x = select(0.0f, CL_FLT_EPSILON, (dp1.y < 0) | ((dp1.y == 0) & (dp1.x > 0)));
			b.zero.y = select(0.0f, CL_FLT_EPSILON, (dp0.y < 0) | ((dp0.y == 0) & (dp0.x > 0)));
			b.zero.z = select(0.0f, CL_FLT_EPSILON, (dp2.y < 0) | ((dp2.y == 0) & (dp2.x > 0)));
			
			// any barycentric(reject_corner) < 0, tile outside the triangle

			b.reject_corner.x = 0.0f + max(max(max(b.dx.x + b.dy.x, b.dx.x), b.dy.x), 0.0f) * BIN_SIZE;
			b.reject_corner.y = 0.0f + max(max(max(b.dx.y + b.dy.y, b.dx.y), b.dy.y), 0.0f) * BIN_SIZE;
			b.reject_corner.z = 1.0f + max(max(max(b.dx.z + b.dy.z, b.dx.z), b.dy.z), 0.0f) * BIN_SIZE;

			// TODO: accept_corner, at min value, all barycentric(accept_corner) >= 0, tile fully inside, no per pixel hittest needed

			env->barycentric[prim_index] = b;
		}
		else // triangle has zero area
		{
			pmax = -1; // won't get included in any tile
		}
	}
	else if(PRIM == GS_SPRITE_CLASS)
	{
		int2 p0 = convert_int2_rtp(v0->p.xy);
		int2 p1 = convert_int2_rtp(v1->p.xy);

		pmin = min(p0, p1);
		pmax = max(p0, p1);

		int4 mask = (int4)(v0->p.xy > v1->p.xy, 0, 0);

		prim->v[0].p = select(v0->p, v1->p, mask); // pmin
		prim->v[0].tc = select(v0->tc, v1->tc, mask);
		prim->v[1].p = select(v1->p, v0->p, mask); // pmax
		prim->v[1].tc = select(v1->tc, v0->tc, mask);
		prim->v[1].tc.xy = (prim->v[1].tc.xy - prim->v[0].tc.xy) / (prim->v[1].p.xy - prim->v[0].p.xy);
	}

	int4 scissor = pb->scissor;

	pmin = select(pmin, scissor.xy, pmin < scissor.xy);
	pmax = select(pmax, scissor.zw, pmax > scissor.zw);

	int4 r = (int4)(pmin, pmax + (int2)(BIN_SIZE - 1)) >> BIN_SIZE_BITS;

	env->bbox[prim_index] = convert_uchar4_sat(r);
}

#endif

#ifdef KERNEL_TILE

int tile_in_triangle(float2 p, gs_barycentric b)
{
	float3 f = b.dx.xyz * (p.x - b.dx.w) + b.dy.xyz * (p.y - b.dy.w) + b.reject_corner.xyz;

	f = select(f, (float3)(0.0f), fabs(f) < (float3)(CL_FLT_EPSILON * 10));

	return all(f >= b.zero.xyz);
}

#if CLEAR == 1

__kernel void KERNEL_TILE(__global gs_env* env)
{
	env->bounds[get_global_id(0)].first = -1;
	env->bounds[get_global_id(0)].last = 0;
}

#elif MODE < 3

#if MAX_PRIM_PER_BATCH != 32
	#error "MAX_PRIM_PER_BATCH != 32"
#endif

#define MAX_PRIM_PER_GROUP (32u >> MODE)

__kernel void KERNEL_TILE(
	__global gs_env* env,
	uint prim_count,
	uint bin_count, // == bin_dim.z * bin_dim.w
	uchar4 bin_dim)
{
	uint batch_index = get_group_id(2) >> MODE;
	uint prim_start = get_group_id(2) << (5 - MODE);
	uint group_prim_index = get_local_id(2);
	uint bin_index = get_local_id(1) * get_local_size(0) + get_local_id(0);

	__global BIN_TYPE* bin = &env->bin[batch_index * bin_count];
	__global uchar4* bbox = &env->bbox[prim_start];
	__global gs_barycentric* barycentric = &env->barycentric[prim_start];

	__local uchar4 bbox_cache[MAX_PRIM_PER_GROUP];
	__local gs_barycentric barycentric_cache[MAX_PRIM_PER_GROUP];
	__local uint visible[8 << MODE];

	if(get_local_id(2) == 0)
	{
		visible[bin_index] = 0;
	}

	barrier(CLK_LOCAL_MEM_FENCE);

	uint group_prim_count = min(prim_count - prim_start, MAX_PRIM_PER_GROUP);

	event_t e = async_work_group_copy(bbox_cache, bbox, group_prim_count, 0);

	wait_group_events(1, &e);

	if(PRIM == GS_TRIANGLE_CLASS)
	{
		e = async_work_group_copy((__local float4*)barycentric_cache, (__global float4*)barycentric, group_prim_count * (sizeof(gs_barycentric) / sizeof(float4)), 0);
		
		wait_group_events(1, &e);
	}

	if(group_prim_index < group_prim_count)
	{
		int x = bin_dim.x + get_local_id(0);
		int y = bin_dim.y + get_local_id(1);

		uchar4 r = bbox_cache[group_prim_index];

		uint test = (r.x <= x) & (r.z > x) & (r.y <= y) & (r.w > y);

		if(PRIM == GS_TRIANGLE_CLASS && test != 0)
		{
			test = tile_in_triangle(convert_float2((int2)(x, y) << BIN_SIZE_BITS), barycentric_cache[group_prim_index]);
		}

		atomic_or(&visible[bin_index], test << ((MAX_PRIM_PER_GROUP - 1) - get_local_id(2)));
	}

	barrier(CLK_LOCAL_MEM_FENCE);

	if(get_local_id(2) == 0)
	{
		#if MODE == 0
		((__global uint*)&bin[bin_index])[0] = visible[bin_index];
		#elif MODE == 1
		((__global ushort*)&bin[bin_index])[1 - (get_group_id(2) & 1)] = visible[bin_index];
		#elif MODE == 2
		((__global uchar*)&bin[bin_index])[3 - (get_group_id(2) & 3)] = visible[bin_index];
		#endif

		if(visible[bin_index] != 0)
		{
			atomic_min(&env->bounds[bin_index].first, batch_index);
			atomic_max(&env->bounds[bin_index].last, batch_index);
		}
	}
}

#elif MODE == 3

__kernel void KERNEL_TILE(
	__global gs_env* env,
	uint prim_count,
	uint bin_count, // == bin_dim.z * bin_dim.w
	uchar4 bin_dim)
{
	size_t batch_index = get_group_id(0);
	size_t local_id = get_local_id(0);
	size_t local_size = get_local_size(0);

	uint batch_prim_count = min(prim_count - (batch_index << MAX_PRIM_PER_BATCH_BITS), MAX_PRIM_PER_BATCH);
		
	__global BIN_TYPE* bin = &env->bin[batch_index * bin_count];
	__global uchar4* bbox = &env->bbox[batch_index << MAX_PRIM_PER_BATCH_BITS];
	__global gs_barycentric* barycentric = &env->barycentric[batch_index << MAX_PRIM_PER_BATCH_BITS];

	__local uchar4 bbox_cache[MAX_PRIM_PER_BATCH];
	__local gs_barycentric barycentric_cache[MAX_PRIM_PER_BATCH];
	
	event_t e = async_work_group_copy(bbox_cache, bbox, batch_prim_count, 0);

	wait_group_events(1, &e);

	if(PRIM == GS_TRIANGLE_CLASS)
	{
		e = async_work_group_copy((__local float4*)barycentric_cache, (__global float4*)barycentric, batch_prim_count * (sizeof(gs_barycentric) / sizeof(float4)), 0);
		
		wait_group_events(1, &e);
	}

	for(uint bin_index = local_id; bin_index < bin_count; bin_index += local_size)
	{
		int y = bin_index / bin_dim.z; // TODO: very expensive, no integer divider on current hardware
		int x = bin_index - y * bin_dim.z;

		x += bin_dim.x;
		y += bin_dim.y;

		BIN_TYPE visible = 0;

		for(uint i = 0; i < batch_prim_count; i++)
		{
			uchar4 r = bbox_cache[i];

			BIN_TYPE test = (r.x <= x) & (r.z > x) & (r.y <= y) & (r.w > y);

			if(PRIM == GS_TRIANGLE_CLASS && test != 0)
			{
				test = tile_in_triangle(convert_float2((int2)(x, y) << BIN_SIZE_BITS), barycentric_cache[i]);
			}

			visible |= test << ((MAX_PRIM_PER_BATCH - 1) - i);
		}

		bin[bin_index] = visible;

		if(visible != 0)
		{
			atomic_min(&env->bounds[bin_index].first, batch_index);
			atomic_max(&env->bounds[bin_index].last, batch_index);
		}
	}
}

#endif

#endif

#ifdef KERNEL_TFX

bool ZTest(uint zs, uint zd)
{ 
	if(ZTEST)
	{
		if(is24bit(ZPSM)) zd &= 0x00ffffff;

		switch(ZTST)
		{
		case ZTST_NEVER:
			return false;
		case ZTST_ALWAYS:
			return true;
		case ZTST_GEQUAL:
			return zs >= zd;
		case ZTST_GREATER:
			return zs > zd;
		}
	}

	return true;
}

bool AlphaTest(int alpha, int aref, uint* fm, uint* zm)
{
	switch(AFAIL)
	{
	case AFAIL_KEEP:
		break;
	case AFAIL_FB_ONLY:
		if(!ZWRITE) return true;
		break;
	case AFAIL_ZB_ONLY:
		if(!FWRITE) return true;
		break;
	case AFAIL_RGB_ONLY:
		if(!ZWRITE && is24bit(FPSM)) return true;
		break;
	}

	uint pass;
	
	switch(ATST)
	{
	case ATST_NEVER:
		pass = false;
		break;
	case ATST_ALWAYS:
		return true;
	case ATST_LESS:
		pass = alpha < aref;
		break;
	case ATST_LEQUAL:
		pass = alpha <= aref;
		break;
	case ATST_EQUAL:
		pass = alpha == aref;
		break;
	case ATST_GEQUAL:
		pass = alpha >= aref;
		break;
	case ATST_GREATER:
		pass = alpha > aref;
		break;
	case ATST_NOTEQUAL:
		pass = alpha != aref;
		break;
	}

	switch(AFAIL)
	{
	case AFAIL_KEEP:
		return pass;
	case AFAIL_FB_ONLY:
		*zm |= pass ? 0 : 0xffffffff;
		break;
	case AFAIL_ZB_ONLY:
		*fm |= pass ? 0 : 0xffffffff;
		break;
	case AFAIL_RGB_ONLY:
		if(is32bit(FPSM)) *fm |= pass ? 0 : 0xff000000;
		if(is16bit(FPSM)) *fm |= pass ? 0 : 0xffff8000;
		*zm |= pass ? 0 : 0xffffffff;
		break;
	}

	return true;
}

bool DestAlphaTest(uint fd)
{
	if(DATE)
	{
		if(DATM)
		{
			if(is32bit(FPSM)) return (fd & 0x80000000) != 0;
			if(is16bit(FPSM)) return (fd & 0x00008000) != 0;
		}
		else
		{
			if(is32bit(FPSM)) return (fd & 0x80000000) == 0;
			if(is16bit(FPSM)) return (fd & 0x00008000) == 0;
		}
	}

	return true;
}

int Wrap(int a, int b, int c, int mode)
{
	switch(mode)
	{
	case CLAMP_REPEAT:
		return a & b;
	case CLAMP_CLAMP:
		return clamp(a, 0, c);
	case CLAMP_REGION_CLAMP:
		return clamp(a, b, c);
	case CLAMP_REGION_REPEAT:
		return (a & b) | c;
	}
}

int4 AlphaBlend(int4 c, int afix, uint fd)
{
	if(FWRITE && (ABE || AA1))
	{
		int4 cs = c;
		int4 cd;

		if(ABA != ABB && (ABA == 1 || ABB == 1 || ABC == 1) || ABD == 1)
		{
			if(is32bit(FPSM) || is24bit(FPSM))
			{
				cd.x = fd & 0xff;
				cd.y = (fd >> 8) & 0xff;
				cd.z = (fd >> 16) & 0xff;
				cd.w = fd >> 24;
			}
			else if(is16bit(FPSM))
			{
				cd.x = (fd << 3) & 0xf8;
				cd.y = (fd >> 2) & 0xf8;
				cd.z = (fd >> 7) & 0xf8;
				cd.w = (fd >> 8) & 0x80;
			}
		}

		if(ABA != ABB)
		{
			switch(ABA)
			{
			case 0: break; // c.xyz = cs.xyz;
			case 1: c.xyz = cd.xyz; break;
			case 2: c.xyz = 0; break;
			}

			switch(ABB)
			{
			case 0: c.xyz -= cs.xyz; break;
			case 1: c.xyz -= cd.xyz; break;
			case 2: break;
			}

			if(!(is24bit(FPSM) && ABC == 1))
			{
				int a = 0;

				switch(ABC)
				{
				case 0: a = cs.w; break;
				case 1: a = cd.w; break;
				case 2: a = afix; break;
				}

				c.xyz = c.xyz * a >> 7;
			}

			switch(ABD)
			{
			case 0: c.xyz += cs.xyz; break;
			case 1: c.xyz += cd.xyz; break;
			case 2: break;
			}
		}
		else
		{
			switch(ABD)
			{
			case 0: break;
			case 1: c.xyz = cd.xyz; break;
			case 2: c.xyz = 0; break;
			}
		}

		if(PABE)
		{
			c.xyz = select(cs.xyz, c.xyz, (int3)(cs.w << 24));
		}
	}

	return c;
}

uchar4 Expand24To32(uint rgba, uchar ta0)
{
	uchar4 c;

	c.x = rgba & 0xff;
	c.y = (rgba >> 8) & 0xff;
	c.z = (rgba >> 16) & 0xff;
	c.w = !AEM || (rgba & 0xffffff) != 0 ? ta0 : 0;

	return c;
}

uchar4 Expand16To32(ushort rgba, uchar ta0, uchar ta1)
{
	uchar4 c;

	c.x = (rgba << 3) & 0xf8;
	c.y = (rgba >> 2) & 0xf8;
	c.z = (rgba >> 7) & 0xf8;
	c.w = !AEM || (rgba & 0x7fff) != 0 ? ((rgba & 0x8000) ? ta1 : ta0) : 0;

	return c;
}

int4 ReadTexel(__global uchar* vm, int x, int y, int level, __global gs_param* pb)
{
	uchar4 c;

	uint addr = PixelAddress(x, y, pb->tbp[level], pb->tbw[level], TPSM);

	__global ushort* vm16 = (__global ushort*)vm;
	__global uint* vm32 = (__global uint*)vm;

	switch(TPSM)
	{
	default:
	case PSM_PSMCT32: 
	case PSM_PSMZ32:
		c = ((__global uchar4*)vm)[addr];
		break;
	case PSM_PSMCT24: 
	case PSM_PSMZ24: 
		c = Expand24To32(vm32[addr], pb->ta0);
		break;
	case PSM_PSMCT16: 
	case PSM_PSMCT16S: 
	case PSM_PSMZ16: 
	case PSM_PSMZ16S: 
		c = Expand16To32(vm16[addr], pb->ta0, pb->ta1);
		break;
	case PSM_PSMT8:
		c = pb->clut[vm[addr]];
		break;
	case PSM_PSMT4:
		c = pb->clut[(vm[addr >> 1] >> ((addr & 1) << 2)) & 0x0f];
		break;
	case PSM_PSMT8H:
		c = pb->clut[vm32[addr] >> 24];
		break;
	case PSM_PSMT4HL:
		c = pb->clut[(vm32[addr] >> 24) & 0x0f];
		break;
	case PSM_PSMT4HH:
		c = pb->clut[(vm32[addr] >> 28) & 0x0f];
		break;
	}

	//printf("[%d %d] %05x %d %d %08x | %v4hhd | %08x\n", x, y, pb->tbp[level], pb->tbw[level], TPSM, addr, c, vm[addr]);

	return convert_int4(c);
}

int4 SampleTexture(__global uchar* tex, __global gs_param* pb, float3 t)
{
	int4 c;

	if(0)//if(MMIN)
	{
		// TODO
	}
	else
	{
		int2 uv;

		if(!FST)
		{
			uv = convert_int2_rte(t.xy * native_recip(t.z));

			if(LTF) uv -= 0x0008;
		}
		else
		{
			// sfex capcom logo third drawing call at (0,223) calculated as:
			// t0 + (p - p0) * (t - t0) / (p1 - p0)  
			// 0.5 + (223 - 0) * (112.5 - 0.5) / (224 - 0) = 112
			// due to rounding errors (multiply-add instruction maybe):
			// t.y = 111.999..., uv0.y = 111, uvf.y = 15/16, off by 1/16 texel vertically after interpolation
			// TODO: sw renderer samples at 112 exactly, check which one is correct

			// last line error in persona 3 movie clips if rounding is enabled

			uv = convert_int2(t.xy); 
		}

		int2 uvf = uv & 0x000f;

		int2 uv0 = uv >> 4;
		int2 uv1 = uv0 + 1;

		uv0.x = Wrap(uv0.x, pb->minu, pb->maxu, WMS);
		uv0.y = Wrap(uv0.y, pb->minv, pb->maxv, WMT);
		uv1.x = Wrap(uv1.x, pb->minu, pb->maxu, WMS);
		uv1.y = Wrap(uv1.y, pb->minv, pb->maxv, WMT);

		int4 c00 = ReadTexel(tex, uv0.x, uv0.y, 0, pb);
		int4 c01 = ReadTexel(tex, uv1.x, uv0.y, 0, pb);
		int4 c10 = ReadTexel(tex, uv0.x, uv1.y, 0, pb);
		int4 c11 = ReadTexel(tex, uv1.x, uv1.y, 0, pb);

		if(LTF)
		{
			c00 = (mul24(c01 - c00, uvf.x) >> 4) + c00;
			c10 = (mul24(c11 - c10, uvf.x) >> 4) + c10;
			c00 = (mul24(c10 - c00, uvf.y) >> 4) + c00;
		}

		c = c00;
	}

	return c;
}

// TODO: 2x2 MSAA idea
// downsize the rendering tile to 16x8 or 8x8 and render 2x2 sub-pixels to __local
// hittest and ztest 2x2 (create write mask, only skip if all -1) 
// calculate color 1x1, alpha tests 1x1
// use mask to filter failed sub-pixels when writing to __local
// needs the tile data to be fetched at the beginning, even if rfb/zfb is not set, unless we know the tile is fully covered
// multiple work-items may render different prims to the same 2x2 sub-pixel, averaging can only be done after a barrier at the very end
// pb->fm? alpha channel and following alpha tests? some games may depend on exact results, not some average

__kernel __attribute__((reqd_work_group_size(8, 8, 1))) void KERNEL_TFX(
	__global gs_env* env,
	__global uchar* vm,
	__global uchar* tex,
	__global uchar* pb_base, 
	uint pb_start,
	uint prim_start, 
	uint prim_count,
	uint bin_count, // == bin_dim.z * bin_dim.w
	uchar4 bin_dim,
	uint fbp, 
	uint zbp, 
	uint bw)
{
	uint x = get_global_id(0);
	uint y = get_global_id(1);

	uint bin_x = (x >> BIN_SIZE_BITS) - bin_dim.x;
	uint bin_y = (y >> BIN_SIZE_BITS) - bin_dim.y;
	uint bin_index = mad24(bin_y, (uint)bin_dim.z, bin_x);

	uint batch_first = env->bounds[bin_index].first;
	uint batch_last = env->bounds[bin_index].last;
	uint batch_start = prim_start >> MAX_PRIM_PER_BATCH_BITS;

	if(batch_last < batch_first)
	{
		return;
	}

	uint skip;
	
	if(batch_start < batch_first)
	{
		uint n = (batch_first - batch_start) * MAX_PRIM_PER_BATCH - (prim_start & (MAX_PRIM_PER_BATCH - 1));

		if(n > prim_count) 
		{
			return;
		}

		skip = 0;
		prim_count -= n;
		batch_start = batch_first;
	}
	else
	{
		skip = prim_start & (MAX_PRIM_PER_BATCH - 1);
		prim_count += skip;
	}

	if(batch_start > batch_last) 
	{
		return;
	}
	
	prim_count = min(prim_count, (batch_last - batch_start + 1) << MAX_PRIM_PER_BATCH_BITS);

	//

	int2 pi = (int2)(x, y);
	float2 pf = convert_float2(pi);

	int faddr = PixelAddress(x, y, fbp, bw, FPSM);
	int zaddr = PixelAddress(x, y, zbp, bw, ZPSM);

	uint fd, zd; // TODO: fd as int4 and only pack before writing out?

	if(RFB) 
	{
		fd = ReadFrame(vm, faddr, FPSM);
	}

	if(RZB)
	{
		zd = ReadFrame(vm, zaddr, ZPSM);
	}

	// early destination alpha test

	if(!DestAlphaTest(fd))
	{
		return;
	}

	//

	uint fragments = 0;

	__global BIN_TYPE* bin = &env->bin[bin_index + batch_start * bin_count]; // TODO: not needed for "one tile case"
	__global gs_prim* prim_base = &env->prim[batch_start << MAX_PRIM_PER_BATCH_BITS];
	__global gs_barycentric* barycentric = &env->barycentric[batch_start << MAX_PRIM_PER_BATCH_BITS];

	pb_base += pb_start;

	BIN_TYPE bin_value = *bin & ((BIN_TYPE)-1 >> skip);

	for(uint prim_index = 0; prim_index < prim_count; prim_index += MAX_PRIM_PER_BATCH)
	{
		while(bin_value != 0)
		{
			uint i = clz(bin_value);

			if(prim_index + i >= prim_count)
			{
				break;
			}

			bin_value ^= (BIN_TYPE)1 << ((MAX_PRIM_PER_BATCH - 1) - i); // bin_value &= (ulong)-1 >> (i + 1);

			__global gs_prim* prim = &prim_base[prim_index + i];
			__global gs_param* pb = (__global gs_param*)(pb_base + prim->pb_index * TFX_PARAM_SIZE);

			if(!NOSCISSOR)
			{
				if(!all((pi >= pb->scissor.xy) & (pi < pb->scissor.zw)))
				{
					continue;
				}
			}
			
			uint2 zf;
			float3 t;
			int4 c;

			 // TODO: do not hittest if we know the tile is fully inside the prim

			if(PRIM == GS_POINT_CLASS)
			{
				float2 dpf = pf - prim->v[0].p.xy;

				if(!all((dpf <= 0.5f) & (dpf > -0.5f)))
				{
					continue;
				}

				zf = as_uint2(prim->v[0].p.zw);
				t = prim->v[0].tc.xyz;
				c = convert_int4(prim->v[0].c);
			}
			else if(PRIM == GS_LINE_CLASS)
			{
				// TODO: find point on line prependicular to (x,y), distance.x < 0.5f || distance.y < 0.5f
				// TODO: aa1: coverage ~ distance.x/y, slope selects x or y, zwrite disabled
				// TODO: do not draw last pixel of the line

				continue;
			}
			else if(PRIM == GS_TRIANGLE_CLASS)
			{
				// TODO: aa1: draw edge as a line

				__global gs_barycentric* b = &barycentric[prim_index + i];

				float3 f = b->dx.xyz * (pf.x - b->dx.w) + b->dy.xyz * (pf.y - b->dy.w) + (float3)(0, 0, 1);

				if(!all(select(f, (float3)(0.0f), fabs(f) < (float3)(CL_FLT_EPSILON * 10)) >= b->zero.xyz))
				{
					continue;
				}

				float2 zf0 = convert_float2(as_uint2(prim->v[0].p.zw));
				float2 zf1 = convert_float2(as_uint2(prim->v[1].p.zw));
				float2 zf2 = convert_float2(as_uint2(prim->v[2].p.zw));

				zf.x = convert_uint_rte(zf0.x * f.z + zf1.x * f.x + zf2.x * f.y) + prim->zmin;
				zf.y = convert_uint_rte(zf0.y * f.z + zf1.y * f.x + zf2.y * f.y);

				t = prim->v[0].tc.xyz * f.z + prim->v[1].tc.xyz * f.x + prim->v[2].tc.xyz * f.y;

				if(IIP)
				{
					float4 c0 = convert_float4(prim->v[0].c);
					float4 c1 = convert_float4(prim->v[1].c);
					float4 c2 = convert_float4(prim->v[2].c);

					c = convert_int4_rte(c0 * f.z + c1 * f.x + c2 * f.y);
				}
				else
				{
					c = convert_int4(prim->v[2].c);
				}
			}
			else if(PRIM == GS_SPRITE_CLASS)
			{
				int2 tl = convert_int2_rtp(prim->v[0].p.xy);
				int2 br = convert_int2_rtp(prim->v[1].p.xy);

				if(!all((pi >= tl) & (pi < br)))
				{
					continue;
				}

				zf = as_uint2(prim->v[1].p.zw);
				
				t.xy = prim->v[0].tc.xy + prim->v[1].tc.xy * (pf - prim->v[0].p.xy);
				t.z = prim->v[0].tc.z;

				c = convert_int4(prim->v[1].c);
			}

			// z test

			uint zs = zf.x;

			if(!ZTest(zs, zd))
			{
				continue;
			}

			// sample texture

			int4 ct;

			if(TFX != TFX_NONE)
			{
				tex = vm; // TODO: use the texture cache

				ct = SampleTexture(tex, pb, t);
			}

			// alpha tfx

			int alpha = c.w;

			if(FB)
			{
				if(TCC)
				{
					switch(TFX)
					{
					case TFX_MODULATE:
						c.w = clamp(mul24(ct.w, c.w) >> 7, 0, 0xff);
						break;
					case TFX_DECAL:
						c.w = ct.w;
						break;
					case TFX_HIGHLIGHT:
						c.w = clamp(ct.w + c.w, 0, 0xff);
						break;
					case TFX_HIGHLIGHT2:
						c.w = ct.w;
						break;
					}
				}

				if(AA1)
				{
					if(!ABE || c.w == 0x80)
					{
						c.w = 0x80; // TODO: edge ? coverage : 0x80
					}
				}
			}

			// read mask

			uint fm = pb->fm;
			uint zm = pb->zm;

			// alpha test

			if(!AlphaTest(c.w, pb->aref, &fm, &zm))
			{
				continue;
			}

			// all tests done, we have a new output

			fragments++;

			// write z

			if(ZWRITE)
			{
				zd = RZB ? bitselect(zs, zd, zm) : zs;
			}

			// rgb tfx

			if(FWRITE)
			{
				switch(TFX)
				{
				case TFX_MODULATE:
					c.xyz = clamp(mul24(ct.xyz, c.xyz) >> 7, 0, 0xff);
					break;
				case TFX_DECAL:
					c.xyz = ct.xyz;
					break;
				case TFX_HIGHLIGHT:
				case TFX_HIGHLIGHT2:					
					c.xyz = clamp((mul24(ct.xyz, c.xyz) >> 7) + alpha, 0, 0xff);
					break;
				}
			}

			// fog

			if(FWRITE && FGE)
			{
				int fog = (int)zf.y;

				int3 fv = mul24(c.xyz, fog) >> 8;
				int3 fc = mul24(convert_int4(pb->fog).xyz, 0xff - fog) >> 8;

				c.xyz = fv + fc;
			}

			// alpha blend

			c = AlphaBlend(c, pb->afix, fd);

			// write frame

			if(FWRITE)
			{
				if(DTHE && is16bit(FPSM))
				{
					c.xyz += pb->dimx[y & 3][x & 3];
				}

				c = COLCLAMP ? clamp(c, 0, 0xff) : c & 0xff;
				
				if(FBA && !is24bit(FPSM))
				{
					c.w |= 0x80;
				}

				uint fs;

				if(is32bit(FPSM))
				{
					fs = (c.w << 24) | (c.z << 16) | (c.y << 8) | c.x;
				}
				else if(is24bit(FPSM))
				{
					fs = (c.z << 16) | (c.y << 8) | c.x;
				}
				else if(is16bit(FPSM))
				{
					fs = ((c.w & 0x80) << 8) | ((c.z & 0xf8) << 7) | ((c.y & 0xf8) << 2) | (c.x >> 3);
				}

				fd = RFB ? bitselect(fs, fd, fm) : fs;

				// dest alpha test for the next loop

				if(!DestAlphaTest(fd))
				{
					prim_index = prim_count; // game over

					break;
				}
			}
		}

		bin += bin_count;
		bin_value = *bin;
	}

	if(fragments > 0)
	{
		if(ZWRITE)
		{
			WriteFrame(vm, zaddr, ZPSM, zd);
		}

		if(FWRITE)
		{
			WriteFrame(vm, faddr, FPSM, fd);
		}
	}
}

#endif

#endif
 ��      �� ���    0	        (     G         ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         ---555444333333444444555244444644644635435435435324333444435435435444435444444244444444444444444435444555444444444444444444444444444444444444444444444444444444453453444444444444444444644644644644644444444444444444333244244444435435444244245444444444444444444453453364244244453453444444453444444435244444444444444644644644444444643453453444444444444444644635635444444444444644644644644444444444444444444444435444444444444444444435435444444444444444444444444435444444444244244244244444244244444444453444644435444444333444444644444444444444444444444444444643444244253453643644635444444444444444444444244444444444444453453453444453444444444444444444643444444444555453444644635444444444635635444444555453453444444444444444444453444444444444777666000              
###GEE___nqovywxxxxxxxxxyyywwwxxxxywxywxywxxxxxxxxxxxxzxxxxxxywxxxxxxxxxxxxxxxxxxxxxxxxvxxxxxwwwxxxxxxxxxxxxxxxyzxxywxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxzxxzxwzxxzxxxwyxxxxwyvxyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxyyyxwyxxxxxxzxxzxxwxvwxvxywxxxxxxxxxxxxxxxxxxxxxxxxxwyxwyxwyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxywxxxxxxvxxyyyxxxvxxxxxxxxxxxyyyxxxxxxxxxxxxyyyyyyxxxxxxvywvxxxxxxxxxxxxxxyyyxxxxxxxxxxxxxxxxwyxxxxxxxwyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxywxxxxxxxxxxxxxxxzxxzxxzxxxxxxxxxxxxxxxxxxywxxxvxxxxxxxxxxxxxxxxxxywvxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxwywvxzxxxxxxxxvxxvywxywxywxxxxxxwwwxxxxwyxxxxxxxxxxwyxxxxxxxwyxwyxxxxxxxwyvxxvxxxxxxxxwxvxxxxxxxxxxxxxxxxxxzxxzxxzwyxxxvxxwyyvywxywxxxxwyzxxzxxzxxxxxxxxxxxxxxxxxxxxxxxzxxzwyzwy}}}���~��xxx`]_#%&       :::9;;435WX	X	[
Y	XVWYZ	\	_	bcdefe
cb	`
a	
bb
ceeeefffd
d
eegfdc	c	d
d
ecb

b	a	a	`^]^___`bcd	gg	h	hggggf	ghhgeeefgijjjjilkjhd`\ZWWVVSQOMIGEDCDDDFEEFEEFGLNPRUUTSNMLKIIIIHIHFFDDDAAA@@@@@>===>==>=<;8 6 4 3239>CG

J	HD	>:64 5 6:=AABA@>>>@DHLO
OLLHGD@?>@BH	LN	
M
	L	JFC?AEJNRS		TPMLJKLNO	T	X\]		X	SNJ	G	EDDGIJKKMP	R	V
YZXTRbbb        EEEBBB+,* W	X	YW	U	UW	X[]bd	d
ef	gfe
b
a
`c	ef	g
iiihhhfed
deff	f	eeed
c	b

a	`_`_]\ZZ\^	`	c	
e	g	
e
eeeeeeed	cbaaabd	eghik	k	k
jigge`[XUUTSS	Q	NKJGGFEDDDCBBDEGJLNOPSTUTTRMMKJJJJJKJJHFDC	B@@??>>>>@@@AA@@@=<964 4335=CIL
L

HC;64557;?DEEBA@@@A
	H
OTUR
NKGC@>==?CH	L
P

P
NJFCAAEINRST	QNJIJJM	PV\	_	]W
Q	LJGFEGIJJJJNRU	XZ	YVROppp222     AAA977   WW	WVWWXZ	^		ac
fh	h
ig
e	c	b	
ac	g
jklnljffe
d
d
c	c	d
eg
g
h	g

eb
	`
_
	^	]]\\\[Z[\	^	
`c	d	dc	
b
b
b
b
b
b	a`_^^_`	`	ad	fhiii	ih	fc`]YWUSQONMKHFEEFFGECA@@CDGJNPPPQSSRPOONMMMMMMMKJHEC@??????????BCDDBCB@>:622368<BH	I
I	GD@ :53667<ACBA?>>?AD	LTYY	T
N	LE?;===@DJM	R
	R
Q	LFD@BDHMORTTPLJJJ	NSW	]

_
]
U	
NJIFFGHIKLLMORT	T
U	TR	R	Nedf111       ?==+++      WVWXXZ\`e
egi	
i
ig	d
b	`
d
ei
lmnpnjgcb
c	c	
bc	ef	f	g
h	f		d
a		`
^
	^
^	
\	Z	\]	^^	_	`
``	a
`
ba	`_	a
_
_	_^_\[]]^_bcbeffdec	_]]YWUUSQNKGHEDDEEHEEDCABCEGHKNMOPPPPPNOOOQ ONNNNNL IEB???==>=;>==@DGE DED@@; :7647;=@CGH
IHB>:87 7 8<=>=>?<>=>DI
QY
\
[
U	O
KC?=<<?BFKO
QQ

P
LEB@?AFJOUWWQLKLLNR	X
\]
XR		MJHHHHIJJJLMOOORRR
Q	RPSUU---        :::!!!      WX	YZZ	^
`bfgij		k
h	
e
a	
_

a	f	loqrsqnie	c
b		c	d
ef	g
g
f	f	d

b
a	
a
_
	^	^	_
	^
_	^^	^		`
`b
a__	``_^	_		__]^]]^]^`	__beedd	b`]\ZXVUR	R	R
OKIFGHGEFIIFC@@ACCEHHKNOONONOPROOOOORPONLKIFE?@>===>;<= ??ACFEBBA@=; 8 9:;<><>ABG

G
ED@=8: 8:;<>>A A<	?>BGO
X	_
c	_
YR	KDA@@?AAGL	QSS

P	LGA?>BHL RVYWQMLMOQ	SV
X
	X	U
P	NLJJJJKLMMLMMM	M
N
P	
S	T
	R
	SCCC"""        999     W	X	
Y	[	`
cehi

h	f	d
ddc	
adhmortvuolgefeeeef	eed
c	
a	_	_	_	^		^	^
	`^^
`ba	
`
`	`
	^
]	]
]]	
_
]	]	\]	\
[[_	_
^^
a
ab
ab`^`\X6v.�ʯ�Ȯ�ȭTP	NLL
H	FFDDDE	JH	DDABCACEDDIKL NQ PNMOQ	PPOOOOQNLNJJ	JGE D?==;;8;::=>ABEFFB?===>>???><9	:@D
IKK		EA:666:;=<@=?
?@CELS[de		a\Q	L	FA???@BH

NS
U
TO

JC@>@EKNP	S	USP
O
OQR		R		T
	R
	T

U	T	P	NMKMM	LN	O	O	L
K
L
K	I
J	
M
QU	
W
UW	;98       999      YY	\	_a	egg

h
g	eb
``b
f	i
nswwvsnk
k
h	f
f	g

g	f
e
edc	
`
`^]]	_	^		^	_
a_
b	`
`
a	
``_]	[	\	\\[\[
Y[Z	[	]	]^	_^^^\[	ZYXWVV3r-�Ħ�ƨ���b�XLHIFEBBC	CDDD	DHFDDBCECCFHMLKNLNNMQRQSRROONPNKKHFCC=; 8679 ;<?>@BCCCBB?=@DFDD==846:BJP	
NJ	D@;45 779;=@@@?@A	I
S\	dhkg		^	S
L		FB@??@D
IQW	YU	O	HC@?BGMOQRTSSSRQ	ONNQ	TV
T	R
NMMQPPPPNLIGG
IKMRV
X

Y[
;98       999      [\]	`
b
e
ee
d
f	db
	`b
gmquxxwsoighi
h	f	f		dbb	
a		`	`	`	_	^	^
^
	`

`	`_b	__G�<}�p��o�n��q)l!D}9}�l|�l��o�l'j
Z
ZZZ"m{�m$p^][^Z?|8{�lV#e~�j|�n|�m_�QS"d}�l��m�Ӷ���H%X}�k#YAm8|�lC&W{�k$WCD	GJ$] ~�n \ GG~�l�k�k��kHJ^�R_�RLLMMQQ&f}�l#fRQON#b��l�m~�l�o=n6C@i6}�l~�m�kz�kz�k89=>$V}�k}�i�i~�lDi7%V~�m#UC��mAo;HCp8{�k?8|�j{�ky�k}�m;	F~�lFy=QEr:�m~�k�i@_836?c7]yU<$R{�k}�k}�ka�RA&Y |�m'jdqr��q��o��oQ
J	C@??@B	E	L	TYYT
M	F@@?AEIMQV[[Z	X	S	NJH	I	P
U	
Y
V
	R		POPQQPPNLHGDFI
L
NR	V
Z^	_999     999  [	]	]	
`b
c	c	cc
b
bbfkqvz|ytomkieeefdb

`	^		^
	^
]
^	`	`
a	
a
ab`
`_]\$l ����������Ŧ���C{:a�Q����������ţl�\Y[
][B{6���Dz7\X	X
V
W��f���Rm�[�˳����Ծ���Ml�Z�˲���������FDk7���Cj6|�i���CCh6���Ak6G
GK	I@p5���Cm8I1d*�տ�������ȱ3b*
G������KNMQSQDt9���Dr7ONNO1k*��������������Kw�b��ʵ�����������;<=<Bf7���ƿ�������_|N@h8���Bl7H���~�hG|�f���74R/�ѿ����ȱ���@	M
���~�g\������������}�h2#J����r<n�\�ʲ���������&TFl<���B�:n|}�ğ����αCu;IC?>>A	EIOU	YW	Q
K
	D???@	AEL	U
^dc	^	
U	
NIFF	I
P	V
	Z
XU
S
Q	PPP	O
NLIG	D
CDG	I	K
RX
^cf999      999    []^
`	_a	a	a	
`a	d
g
ntyzwroki
gebb

b_^]]\^	`
a	c	d
c	
a	_]	^		^
\	\c��{�ؿ[ZCz5�׽?x3ZZ\ZAx3�׿	\Y	X	
[@y4���Cy4UR	RPQ z�a���O�־z�bO������L�׿{�d	F������EAg5�տBd5z�a�־?Ag5���?i2
KJML@p5�ԿAn6G	������GGz�d���J������LMO
RPR=s2�־?p2MMOMMK IFC�׾=a2x�a�ս1Z'>=>??=@@f4�ֽCd7@A@Ah4���?m2L�տ{�c@w�`�־3������4{�a�־	FO����cBr8�־Cc47�׾x�]4y�`�־==�־w�a>?���~�cCi9�־E�6��w	o
|�c�־	IDA@AD	J	LR	W		XV	PHC??==BJU
_
g
	ke[QJGGI
M

S
Y	[	
YX
U	RPPNKJIJIGGG	GGHO
W_lv:::        999    	[\]

\	
_

_	_
ab
chox~��xqlheb
ca	
a	
`	_^[[[]
ac	cdec		`]]\	\[\Aw4�γ@x1	ZY@u2�ʹBv0YXXZAy0�̳[ZYV=s0�γAq/QQNLMx�\�ʹN�̳v�\M������K�̳w�[H������B>a/�γ>`1t�Z�γA?e1�δBk1
LNK	M@k2�ʹAj1J������
GEx�[���I������PQOPQP?n0�Ͳ@o0MNLIHFE@?�̵?c/=������?>@==>=?c-�γ?_.@@ G?k0�γ?j1F�ͳu�\<y�Z�˴6������5x�Y�̵CP�̳y�\Co4�Ͱ@^35 �γx\7y�X�̵==�γy�[9<���v�YFo6�γH�8�� �vi	{�]�ʹHCAABDINRVVTLC?><9>HU_eed
`TJFEGK
M
S
	X
Z
Y	XV	Q	OLJGHIIHHGGG
G
GO
Zev�9:8      888     ]]	
\
]``a
aelv���zpjd`
`	__
_
	^		__	_	^	
_
	`
b	ded
c	
b
`]]]		[ZZ]@u,�Ĩ?v1[	Y<s.�ƥ=u,Y
ZY[At0�ŧ[XVR=o/�ƥ?k0NNLLKx�X�ŧM�Ũu�TJ��}��J�ŧw�S
C��~��~=:^*�ƥ=],wV�ƧBAe/�ƧAj0KK	KL@g0�ƥ@g/J��~��}GGu�U��K����OTQQPM<l1�Ǧ?k.N LJHGED@A�Ǥ;b+C?��}w�W?@>>??<`*�Ť>b.B	FJ=h/�ƥ=d->�Ũw�U:uT�Ƨ4��|��3u|W�ŨB
J	�Ħx�X
My�V�Ĩ�Ũ�Ĩt}U6v�V�é><�Ťv}X7;��}z�YA|2�ŨO�;"���H�7�Ĩ�ƥJ	FCBBCGK	O
R
S
P	MF?:;; >FS^dd
a	
]XOGCEJO	Q
V
Y[
YX

TNKJHHIIIG	GGGI	J	JR^j}�;8:     999      ]

_^_bbc
h
r{�����xqhd
_	^		^		_^	^	
`bb
ccdf	
e
e
ed
c	`_	\\]	\\[	Z@t.⼙@t.��s供弛㼜<q.[��u⽛㽛ྚj�HX	U	TS>m)⼜彚㽚⾚w�PJKr�NཛྷJ㾘t�OK��t��sJ⽛tM@��t��v=>]*Ἒ9_+v}P㽚E?e+供;e(HHIH=f,㽚=d,H��t��uHIt�O��uL��t��uNPQNLO<j(⾚徘㽛伙s�QGDs�Q伙潜Ὑ��bLDE.X!㽚t~P=???=>_,㽟Ἒ㾘��uF=b*㽚;^&; 㽛q{M=s|Q㽚5��v��u3szO㽚B
I罚x�RM%T<`*>]*⾚szO7szM供99ཛqyP8?��uu�QG�5㽚O�=#� ��⾚��dCn-M
HEBACG	K
NPQ
	LG@;9<?IPY^``]ZSLFE	HKPT
V
X
[Z	U	O	KIHHHGHJ	G	C	EFHK	NVao��999        999      ab
cdefkv������{og`]

\
]		^		_	_a	c	
d
d
e
	g	g	gfe	ddc
a	^	]	]]	\	\	\\;p&ߵ�=p&0k!?q)=r(=s&`Y|9ү�>p(9o)@k*X	P
NNP
;h)߳�czC>e'9e*ħ{.ZHrGߴ�
L޴�s�HJ��k��mD߳�uyH@��j��l@<_'߳�=]&qzHᴎF<b(ߴ�<b(F
FIG<e(ߵ�@c*	I��i��kJLs�K��lJ��lЭ�Tu8PPMMJ9e(ഏcxA4c%<b(ħ{+].Zŧ~cwB:d'?e+!UH GEDgsAĥ~/U!?>=	@9`(್gwB;a'/XA:\&೎=Y$;ಐpwJ:pvGൎ4��m��k1vrIߴ�B
Lߵ�w�LR
J	B=߳�quK6svIᴏ77߳�qvI<	C��lu�NG�4್��w �""��೎v�I	X
U	L	GEBCFI	LNN	IB=::?ELPWYXXVTNLIHJNQ
UV
Z	
ZWQ	KH	FHHHGGFDBCEG	I
M
Wf	v��999       :::      gi
h	k
o	s{������{md_
\		[	[^
_

`c	e
h
h
h
	g	fgggf	dec	a_	_	_^]\Z	\=o'ݭ�7p%	\\Z	YXn�Dٮ�	WSROOONO=g&ܫ�;d&KKݭ�:a#Ip{Cٮ�Lڭ�pzEI��c��bC��U��r��ç{��cD;^%ٮ�:]$pwDڭ���b��m��dR G	EHI��lۭ���mJXo8̧{��d��c��rTp5L��e¡t¡s��c/bPML<d#ٮ�:`$HGܮ�:a#9d%ڭ�;f'NPLIGEC"P��T��l@@AB=]&ܬ�9\$@=:<X#ج���k��a��tt��csqsE0��d��c . noCٮ�F	S
ݭ�t�GV
Vr6��c��c��s=S#.L��sڬ�|yL6��S��s��c��d��lCw*F�2ڬ�êx��k��X���Y��v��e��eN	H	G	FGIJL	K
G	C?=<>CHNOSVVTRSON	J	JKOQ	R	W	[
Z	UP	L
J
GHIHDDEDCADGINYh	v}�999        999      rvw{�������vkc^[
[
]
]`a	d
g
hi
k
jj	h	gh	h	f	ecc	
`	^	`a		_]
\
]
\	&c��\��M[YZ	V
Vl~;צzQ	N	OKJL
MN:e$ئx:b!	JK٦{=b"Lrz>ؤ{Iqw@8^$HVl2Xl1H TpyArw@pw>Vl2G PmsBO<\#nt=pt@ns@;\#DFG
HJ��Nۧy��NLLpy@ox@rw@rw@LKUp1Vp0o{?o{?]NII:`ۧx6`#JMإz:f!;g"צx;d&OMJE;] ms>@@9Z!ץ{@BAC:Y"צz;X >:;Hnq?nq@op>Re.qp>pq?pm@2.SV/VV2,6P"qr@O
]զzm�B^?f(pu>orAVb06E��\٦{Sb/8
 Gmr?qr@quAVq2e+~"z�Hb�>�Lh�C�-� t�Bp�Aq}AR
MJ
H
GH	IJ	GCA@@AA	EGILQTUSQRQOM	L		LMQ		RUV
V
T
P	MJH	EED
A

A
BCB	CDHM
	T

\	fnnj999        999      z�����!� ����vjd
a^]
]	`c	b
ef	g
hjjjk
j	h		g	ghg		fc	
b	a
cd
a	_]	`	_]Xv/��eo{9p{<oz<py:"YSn,ǜkou:mu8nu<nu<LL	MN;`"֞o��Hiu9ow:��d,\
Miv8՞qIGIKL
NONM	NLJGPnp<PB@@ADC
H
G
HI*Y��\�Hnt9	JI	IH	JLMMMMNOKJK8`՟p��Ilw9mx:��b/e0b��b��Hsu:mt;mr;!PSc-ǘljp9oo9�{G��\BA??:W ؟r�yGml:jm;<S<=;;9763-)((0<I
WgԠqs�?c	W	JB:57ml9ՠn999<	=
F	P\s��#�%)�#$��r
eY

TO	M	JI
GGHE	BABBAACDGJNPQRTUSPNNNN	ORTUT
SQ

NK	G		CCCBCCCDDHM	R
V
[
^`][999       999      |���������vmfd
a	`	^		`
b
ff	gih	jkk
i
ggggfg	gffeddda``_		]^	\Tp.��P��O��O��O0\Mzx>��O��P��N��OMOOL+\��O��O��O��OQj.MKQh*��OMMJOS STRNNMII*U��Q'SAADABFIIGFH,W��O��O	HG G ILKLLJLLKKOL,^��L��O��M��OQq*XVQl*��N��N��N��O+TEzs<��N��P��P'SB><;+N��L��P��N��KP])< ; ;8510- ., ,,5>N^r��N]�3n_
PG	?<	;Q]+��O:99<<A
GUi��� &�!$��rf	]T	O	
M
J	IHGGFDAA?>>@BHJMOQUWYXQ	NLMMO	NR
UW	
U		R		P	LGBBCDEEGI	FJPV	X	VTST	R	999        999  z��������wmjb`ab``c	degj	lln	l
k		j	j	j	j		gff	e	d
efecb
b

a_
[
]Y
VS
QNMNOOO	OPN	PQP	
P	PROMIIIHJLPTSRUVU	SRSOMH	FDBBBEFHE	GG	EE		D
	CFHHJ	IH	J	JLKNMMMORTVXX[YWTPLFHHIH	FD	AA	>?	<<=;:;988999850//-,.125>
M
`|��ziTOG>;776788:	=D
P	c
|��"��sg]
TN	M
H	F
G	I	IHFB@>>=>?DFLR	V
V
V	VTR	PKJ	I
KL	O	
SXVR
MK		I
F	BBE
F
D	GMP	R
SSRN		LL	LM999        999   u|������{tlfb```_
_

`beimo	m	lj
i	jk	k	
k
j		h	higgffc	a		__[	\	Z	W	S	R	R	OOOOPQPR	STRQ	PNN	MK	K
JLPQRUWVVWYVSRPNJHFCABCFFFGGFFFE	FHGGHHI
IIHIJMRTVX	XYZ[ZYRRMJJIKJIFBAA><=<;;:;999975200//100216=	Ld�#���uaU	
KB=7433445	:BMXftz{zvpg
]
U
P
MKK	K		M
K
F	C>===<=?D
I
LPSVWXVQ	L
J	IHIL	O	TW	VT
PNKK	IHHG
	H
KP	R	
S
	R
NLJJI	J
H98:       999    muw|~~{wqhc`	^		^
]		^
	^		`	dh	knm	
k
	j	i
i	j	k	k		j	k
j	
igg	gec	a	_]\	[
ZZ
WWS	RQOPQRSSSSTRPNMMNNORTVXXYZZZZXXWTQNKHEDCDCEDDFFEEEEDFHGHHGHIJKOSVWYZ[[ZXUSOOMMKKLHEDA>=== ==;<; ; 9 76341//1221310/4;	K
e��"�$�!�i
ZJC=7310/01	7>EKR\`bddc`[

U	SPM
M
N
M
	IC@<:;;;<@DHLPTWXWTOJGGHIL	P
S	VV
U	T
P	NNLKKK	L	O
S
	S	OLIHJIHEC98:      999     fmpuxzzwrlea
^\[\
_

ab	e
hj	
m
mlk
i
i	j		j	
k

k
j	j	
iff	db`^	\
[ZZXXXWTRRRSSSTTRPONLLMOPSWUYYZW[[[[ZWXXTSQNKGDBABAABCCBCDEEGHEFFFFJPSVWY	ZZ\[XURQPPMLOMIGD@>=<;>?<==<:953212123464341 103<J	`��%�#$�!�mYK?60.-. /127<?@CIN
P	
S

U	
U	U	
TRSRPNM
	L		FB@=;::9;? DHNRUW	USPKGEFHJK
QT
V
X
X
XW
S
P
ONNOR
Q
OMJHH	IHFD@@;99      999    chnrtvvrmhc_^
\	\	_b
dce
h
	j	
l
ml
l
lk
m	
lllj	
h	f	f	c	
a		^	]
\	[
Y	YY
W
V	U	U	U	U	VV	W
W	VTS	Q	OLKKLOR	UW
[
Y[Z]\
^[[[ZYWXUSRPMIDABBBBBBCEFGGGFDBBEGJLQ	VX[]\[ZVRONOPPONKIGA?	==>?>===<<:7311113467773420/-0:Ha� �+�((�%�k	XH;	40.,-0779;;;;?B
G
J
M	L	
M
MO	O	QP
O	MID
BB@	>=<<=AE
KORT
U	
T	PJHFG	G	HH	H
NS	W]`a`Z
S
RRQS
TO
J	HGHJIFA?@C999        999     agkopqpmigda_
^		^		^	
_
b
d
eg
i	k	k	k
mno	n
	ki	j	
h	gd
b

a		^	]	]	
\	Z	
Y	XW
W	UV	UW	WYWW
V	TQOOMNNOQSVXZ[
]^^^_]
]Z[ZZXXVQMMJHCBAAAABBBCEFHGECBDFHLOS
VWZ[ZXUQNMNOPO
NLHDA?==??>=><	:;86432114676785220--/18CXz�$�!#�$�h	VC710001444577778:@BD	E
F	G
I	K	
L
M
	LJHG	
F	E	DBA@?@C	G	J	NPPPMKHGFG	GFD	E	K		T\eklg
^
Y
U		T
	R		R	
P	KIHHIHEB@@CE999       999  `cgkkmljihd`^]
	^
]	
\		^	
a
ce
g	ik
lno	o	m		j		g	gf
ed
b

a		^	]	]	\ZYWX	XWZY	Y
WW	W		UTRPOOORTWXY[]^a_aa_	``\\\\YXYXSNJHFCA??AAABBCCC	DDGFCDIK	NSWV	V	WUVTPPPPQPNNIGE@@A?A@>?>;994344545667987543/0..015 ?O
m� � �{eR	@7443543323565567;=@C	F	F
H
HH	IH	IK	L	M
M	LKIEBCEGIJJJJIIJ	IGFFEB	E	Q		_hpusn
f`
Y

S
P	
MKKLLIGB@ACEDB799        999     	]`cfhklljida]]

\		[	[	[	^	_b	d	gj	lm	m	lj	i
f	
e
ef	ec	`	^	
\	\[ZYY	Y
ZZZ]Z	X	UVUTTSSTTVWZ\\\^`aba	
ca`
^^_^]YYWUTNKFDBB??BBBAABBC	E	DGG	IJKLNQT	TPOPPPPQ	TSQNKEEEACD@A@@><98542213689;:97864 2/0/../03;	F
k��"� taQ	E9	676544333432456:<AB	D	E	EC	F	IK	N	
Q
TU	WW		UQM	IHGECAABGJM	L	
J	
GECCCG
[
q	~� �xsh`W	O	LKKL	MKGB>?BFGB?799        9:8    Z
^_bgjlljiea^^ZYY	[	
]
ab
d
ffgi

h	
fig
e
ef	f	eb
	_
]	[Z[Z	[	Z	
Y
Z\ZP.                                                -%        @^\'                                                        
 =NN	LL	NM= 	                                           3/      (9;9::7641
,                    Y��#�!ua	P9    )234
200158;<@	?	@		@		@	
A
F	MP
T[
_`ba^	
Y
RNIF?><;>
D	
J		LJH	ECAAEMf��"�!�~scWQ	M	L	M
NMI	GDA@BCDC@;98:       999      Y
	]_egjjjihdb
^		\Y
Z
Z[
\		^		`aef	g		g	f	g
	hf
h		g		e
cc	
b	`_	\Y	YZ	[[[	ZY5  `eV����ٺ�ں�ټ�ٺ�ؽ�ټ�ٺ�ټ�ټ�ؽ�ؼ�ټ�ټ�ٽ�ع�ٺ�˰\eX@H=�ؽ�ع�ٽ�ٺ�ٺ���aX�ں�ؼ�׻�ټ�ٺ�ٺ�ٺ�ٺ�ٺ�ټ�ټ�ټ�ٸ�ؽ�ٺ�ٺ�ټ�ټ�ؼ�ټ�ػ�ؼ���v�p$KJJI!v�p����ؼ�ٺ�ؼ�ٺ�ټ�ڽ�ؼ�ں�ؼ�ٺ�ٺ�ټ�ټ�ڽlua%*(�ټ�ٺ�ټ�ڻ�ؼ�̭/ ^eX�ٽ�ؼ�ں��|,97764310( ����ڹ�ٺ�ؽ�ڻ�ؼ�ڹ�ټ`eV5��$�"ydYu�q�˲�ۻ�˯���\fV(,& 1 3 435  67;>;<>@@FHN	X`g
ikmk	kb	
Y	TJ@	::9<>AGIGEA@BEN\|�!�&�!!�{j
WNML	OQRLFB?ABDBA
=:;999        98:      
Y]
_
chiijjhec_
\	ZXV

Y

\	]^
`
b	c	f	ggf	hh	f	dc	
b_
_

a
`^	
]	[Z	Z	[Y	X	X ����յ�Զ�յ�յ�շ�յ�յ�ճ�յ�Դ�յ�յ�ִ�յ�ִ�ճ�ֶ�յ�յ�ִ�Ӹ�ִ�ִ�յ�յ�նPTH9	[C1:-�ֵ�ճ�׵�ն�յ�յ�յ�յ�յ�յ�յ�յ�ֶ�ӵ�ն�յ�Դ�յ�Զ�յ�յ�յ�յ�Ե�Ǩ:FF:�ȩ�յ�ն�յ�Զ�ֵ�Դ�յ�ִ�ִ�ִ�մ�յ�Զ�յ�ֶ�յ�յ�ǫ�ճ�յ�ִ�յ�յw~o6 1 &*$�ǫ�Զ�Դwn * 864244(wn�շ�Զ�Դ�Զ�յ�յ�ֶRTH`	�$�#'�$~g
Vx�m����ַ�ֺ�շ�ָ�շ���\cT07:<=;9	788<B	L	R	Zcnwz}�}zkZ	O	C<889;?BDECB?=@H	[	o!�$�!&�#$�"�l]
NKIK
NNIECABCCB>937=999        999      X\	^	beijkjhfb^\YW	VW	Z[	
[	^
a	c	eg
g
fed
d
c	
b
b	a	`
a
`	^		^	
\	Z	
YXWU5SQF�ϯ�ί�Ϯ�Ϭ�Ϯ�ϰ���]bS^`T^aQ\bQ__Q^aQ]aN^aR]`P_cP__Q]aNx|i�Ϯ�Э�Ϭ�Э�ή�ϯ�Ϯ86.CZ0``R���w{ha`R^cN^aQ^aQ^aQ^aR``R`aQ`aQ^aQ^aQ^bO^`T]`QabR\bO{|h�ϰ�Ϯ�ϯ�Я�Э�Э{|hCE	 {{i�ή�ή�ϯ�Ϭ�ί���io\__S_bR]`P\aR``R^aQ\aR`aQ]`P\bQ����Я�Я�ϯ�Я�ϰ�ίaaQ 867����Я�Я��t" 54551 x|i�Э�ί�Ѭ�ϰ�Ϭ�Я�ѬPQGDr�+�$,�'�eO4
 QRH����ұ�б�ұ�Ѱ�¥_bS
"@?<: 838;	AHS
]iq}��!�"���sZ
M
A?	99;=?BAAA??>CNj�,�)/�-#�"�yZQ	JKJJK	JFCDDEB?=954:B;99       999     WZ
\
`d
hijihf`]
\	YWW
X	Y	[[
^
acef
g	f	c	
bc	c	
b
b
c	b
`	^	]\	[YWX
W[	��o�Ȥ�Ǩ�ǥ�ɦ�ɥ�Ȧ544554445535'yxd�Ǩ�ɥ�Ǥ�Ȧ�Ȧ�ɥ74,B[Q.  &&%$#"!" #$%(&)()����Ǥ�Ȧ�Ʃ�Ǩ�ȥ��� GI ����ȥ�Ǩ�Ʃ�ɧ�ȥQPB!'%%%%%$#"!  ����Ȧ�Ȧ�ȥ�ɣ�Ȧ_^J87 76"����Ȧ�Ȧ���779]_L�Ǩ�Ȧ�ɣ�Ȧ�Ǩ�Ȧ�ǨQPB 9U}$�/�,&�&}[I;51) '*!}yg�ɫ�˫�˩�˨���56,0
63578?IS
^jw��!�!(�%*�'"� �w^O
	C@	<;;=>?=>@AA?
HY|(�%6�67�4 ��
eNLMLJHFEEDEFC>9779>	D	I;99       999     	X	Y
	Z]
adehhgdb\X
V
U
S
	T
Y
	Z]	^
	`
b
deee	d	db
bc	b

b
b
_
][ZYYZ[	\] ��r������������������  edccddd
degc`
 7 ^YJ������ɿ��64*AVSPOOLHCA??@BDGJK	MLK	J ��s������������������  KL ̿����������������64*2FFEECA?>;	: ��s���������������]ZK:8999 " wt_�����)&<NM?�������������������SM@.B\�#�""�%�!tV
C;3/+++" :7)����ġ�ƣ�â�ŤmiW  &3 5	6;
F
T^py����� )�&+�*'�$�|cT
G@
;99::;<???BAQn�4�5=�>3�2�mZLL
L	HFBABC	C	DC?956:@G	L
M999        98:      
V	X	
Y\	_aceefdb^[X
V
U	
U		X	
Y
[

]	_
a	
a	
bbb

d

d

b
bcb

a		a
_
]	\	]	]]_`	bd��l˽�̹�ʺ�̻�˹�ͻ� 
cbdd	e	fde	dab_0^XE˺�˺�˹�˹�̺�˺�42(B	TTNN
JF
FBCCFGHIJMLLL	KI��m̺�ʻ�̻�ʺ�Ⱥ�˻�  ML  κ�Ⱥ�̻�̼�ʻ�˹�43%3FGFC@B<=:9��l˹�̻�ɺ�ͺ�ɺ�]WD	:78966+ _WF̻�̹����D?0RI<ʺ�˹�˻�̻�̺�˹�˻�QJ;)3
J	b�!�!"��m
P	A3.+*) +.7 " 
xq]̾�˿��������h7<
D	Rbs�������&�#,�++�&��fT	E?<:978	;>AAABF	_�#�#6�57�8&�'v_TL	JEA??@CDB	?;867:@G	L	MN98:      98:      
U	U
VYZ	\_`abb`]\X
W	V

U		T
UV

Z
]
`
_

ab
d
cc	d
d
c	c	
b	b
`	__a	bcd	e
ij	��gʳ�ϳ�˲�̲�̲�̴�  fccdcdca	`^	\]1_T@ͳ�ͳ�Ͳ�˳�ͳ�ͳ�71&>	QNKJE	GCGHJ	L	M	MK	L	K
LLKIJ��c̴�̲�ʹ�Ͳ�̴�̴� IH  δ�̳�δ�̳�̴�ͳ�60%4	GCC?><:<:8��dʹ�̳�̳�̳�̳�_SA998764 44OI6˲�ʹ�ʲ�xlT̲�Ͳ�α�̵�̱�̳�ʹ�RG9  "
-9Pf�#���fG	;	.&&& )05<D 6 zmW͸�̷�͸�ɸ���t
-CR
fx��������%�!,�+*�)��bNB>87568<?ACDLYz%�%0�,0�.%�${dSNH	E@>>@@BB=7458=A	H
	L	MK	K
799        799      
T
T
S
U	W	X	Z\^_``]Z	X
V

S

S

T
T	TX		[
]_bbbb
cfe	c		c	
d
	c	d
bcfhi	i	k	l	l �_̬�Ϋ�ͭ|Ϋ�̬�ά�   	ec
ced	dba]^[[1_Q;ά�έ�̭�˯�ͬΫ�8/";LKGGIIMPQQQPONL	LJIHGI�}_Ϋ�̬�ˬϫ�̭�ά�   DB   ̬�ͮ�Ϋ�̭�̭�Ϋ�8.$2DB><;::::;�_̬�̬�̬�̮̭�`N=888985869 )!��{Ϯ�έ�̭�̬�έͫ�̭�ά�{gN&)2=Qg�"��|Z@3*&$( . 6	:@@?1 xkQ˲�α�˳�̳�xlP 
P	_z�!�#����}��'�")�')�&�~[	H
	=82247;>?>DI
Zr%�%3�.3�-#�"�
kY
K
	FA@>@ @@@>:7316>EF
IJ
I		I	I7:8      999      
S	R		R
	T
TTV
Y[
]^^
\	Z	X
U	U	T	T

UW
Y
Z[^	_
`b	c
	c	
e
ffh
h	ih
iik		l
m	
m	
k
	l
m�xYϥ{ϦyХzͧwϥzΤyedee	dec^ZZXW-bM8ϦyЦyΤyϥxФ{ͦz6- 8KI	G	K
OU	T	VVUTRPNMJI
G	GG
I�yXΤy˧yЦy̥yϧwΤy  CC   Τyϥzͧwϥ{ϥz̥y8, 0=<<<: 	<;:	;;  �x[ЦyͦzΤyΤzѤx`M88789 96:;:; `M8ϧwͥ{̤zϤyϥzФ{ͧwzcI  *-5= Pf���uU90'(&,29=?>>= . ��o̬�Ϋ�ά�Ω�TE5.t�� ���zvv|�"�$+�(&�!�uTC	95347:=>?A
ETj�*�+5�4.�*��	c
Q	IA?>?BDB=874 44	<
BG	H
I	IH	IH999        ;99      Q	PO	Q	
S

S
UWY[[\[
YW	U	
TTTTV
W	
V
Y

[	]`c	c	ceg
j	k
k

k
lmmn
o	o	nl
k
l�uTΟs͟pПsΠqΠqΟs  f	d	db
	a`^]YU
R
Q)bJ6̟sПsΠqΠqϞpСn:*7LM
P
	T4                            ��jПqϞpПqПsџqΞt   C	D  ΟsПqϟoϞpПqРp8*.;99:<;;=;< �vS͞rПqΠq̠qПqaI5 76789<;::,��iПsϞpѠpСnПqΠq|_D  ),.3= Q
e! ��kH
/ *() +047::8:995,"Ϧy̤zʦxЧz��n�,�&*�%��{mmq}�+�%+�)#��iM>53258;>?C
F	
M	_v!�!1�04�3&�&�o	
UIB??	@B	E	B=93258=
A

D
GF
G	IIIG	999        ;99      RQOOPQ	
S
UV
WWWWWW
U		T
TTSS
T	T
W	XZ]	
`d	g		j

lmmoqst	t	s
r	p
n
l	j	m	�rOΚkΛiΚkΚk̛iЛh dcb	`
_	\[
[VQOM+`H2ќjЛiΛiΛi̛iΛi6&;TZ	V&S=+�rPϛlϛl͙j͜jΛiϜjΛiΛiЛiЛiϝiЛi͜lΛiҚk͜lΚk̛iЛiΛiКkΜhЛi HG   ќi͙jϜjΚkΚkΛi7),::	:	:;;==>A�qNΛiΛiЛiΛiЛi`H2999::;=8 +��eϜjЛi͜jΚkΛi͜jќj() +-
,4@U	k! ��b
@
. + )  +,)          	 # �\͡rΠqϡrРpcK5P.�+&�%�}oeip~�&� (�&#�y
Y
	@	834 468:=B	FLU	j	�#�2�/0�- � {`
MF	CABB	C	A=841	28?C	E	E	FFFGHGF999       999      VSQPPPQ		R	
S

U
U
U	V		W

X
W
US		R	R	R	QR	S	U
WY]chk
no	qqt
t	u
u
u
s
r	o	oop
�oJЗdЗcЗdіdЗcјd  c	T
4 ECA?=<;89)^F0ЗdіdіeіdјeΘc8(?	\_-`G-Зc̗dЖeЖeјeЗcҗeЕcіdјdЗdЗdіhҘdЗcϙdїfЗdՖcЖeΖeіeҙbЗdіh  IH   їcϘeϖcϗfїfЗd8(+;;=
=<<<>BB�mHҘdЗcіdЗdјe`F. ==<::: 8(Î\ЗdЗcіdϖc͙dЗcіeΘcÎ\(+-/8B 	[	o"�! �w[A/*)#  mT:�sOϛm͜nϛlОj��]�iKS=+	T>,ϛl͜lќjМm��d
&�%�~ogdiq~��!� ~iM

:
446 57:=B	EHMWr�$�!-�+*�'�o	Z
M	IHGFB?954 57
:
?DCCCEFFFEEB999       888     ZVSQ	Q
Q	Q	Q	R		T

U
U	
U	V
UUS

P	
P	
P	QPP	R
T
U		Y	\
ad
g
lo	r	r	r	rrs
s
s	rqrvv�nGѕ_З`ϖ_Җ`ѕ_Җb  UbG-7(6)8)8(5(7'6)7'4*8&�Z7З`З`ҖbҖbϖ_Εa9)E
\	^ ��Yі^ϖ_ѕ_Ζ_ϖ_ϖ_ΕaЖbЖbѕ_ϖ^ϖ_З`і^јaД`ѕ_ϖbΖ_ӕ_ϖ^Җ`Ζ_ϕa��Q 
HG	  ϔbϖ_Ԗ`ϖ_ϕaі^8(-=<<=>>>?AB�mHЕcΕaѕaϕaЖbbF.!??>=	:4'��Zѕ_ї\Ζ_ΕaЕcӔa�wMT<(ѕaϖ_ЖbS=$+.6C Xp%}# {lV	@	1,  
oQ4њgϗfЙfИiљbҗi͘e͗hϙdЙf��X_G1ҙeјeИgϘeИgU;*_�tggfjr�"� �kWC	74467:=B	F	IH
M
Vv�'�&.�,'�%}j	Z	OK	I
GE@	;523;?B	CBBA@A	C	DCC?=999        9:8     ]	Y	T	R
QQQ	QQ	R
	S
UV
U	S
Q
	O	O	O	N	ONP	R	
U	WXZ	]_c	g	j	
m	o	o	p
o	pqt	t	t	u
wu�oEϖ^Ζ_͖]ϖ^Ζ_ѕ_H5(ѕ_Ε]і^ϖ^і^ϖ^і^ϖ^і^ϖ^і^Ζ_ӗ\і^ї\Ε^җ_ϖ_U<(6	]J+֖_͕^і^Д^і^ϖ^ϖ^ї\Ε]Εaϕaі^ϖ_̗^Δ`і^ϖ^Ζ[ϔ\ΕaΕ^ϗ\Ε]ϖ^ϖ_dE,'
IG Ӗ^Д^Η^͕^ϗ\Ε]7'-><>>>@EDEB�nEі^ї\ѕ_ϖ_ϖ^aF,"A?>:5(��Zϖ^ϓ]Еcі^і^Ε^�xI G2��Yϖ_Ӗ^bE0 #8 D[
l"w" vjN 8,# 
�yNҕcЗ`ЕdЗ`ЖbіeҖb�xO�nIϗ`Җbϕaϗ`ЖbϖcєbӗaЖbnQ2E
vmhggku���s\J:3355:?	C	DDGHO[}�*�&,�)!�xi^	T	NG
D?:775:@EDB?>??AA@>=	;9999        999     c^	[	W
V	T	T	S	R	Q		R

S
S
	R

P		OMOON	POPRS	UVXY[	_c	
e
h	
lo	
p
p

qs
t	u
	v

w
u
s�nDі^і^і^і^З`ΗZ  H7'Д^Җ`Ε^ϗ`ѕ_Ε]ѕ_Η^ϖ^ϖ_ϖ_і^ϖ_ϖ_Η^ϖ^Е]җ_�nG[	E6(і^Д`З_ϖ^ѕaі^Җ[і^ѕ_ϖ^Ζ[ϗ\ϖ_ϗ\ѕ_Ε]ϖ^ї\ӗ\ϕaҘ]ϖ_ϕaЗ`�nE	@FE   Εaі^Η^ϖ_ї\ϖ_B4$,,-../2// 0�yLϖ_ϖ_ѕ_ϖ^ϖ^bG,$@=:5	�yIϖ^Д^і^͖]ϗ\ϖ^�xL
 0(ÍX͖]ϖ_[7$Jcq"w#p
`D 0 nP3Ε^ΕaЖbҗ_ϖ^ϖb_G+     R:&[ϖ^ѕ_Ζ_ЖbѕaЗ`�mG#qnmj
jq|��zdO
C84468=?AABEHR	c�#�*�%+�'�zmaWM
	C<966 ; >ADFC@>=?@A@>:778999        98:     i	ed
_	
]	X	U	U	SQ		ON	O		O		O		O	MOPOPPR
R	R		SS	UW	X	
Y^ae
i
mp
r	t	u
vwwxu

r�oEϗ\җ_і^З`і^Ҙ]  X
5(8(6)8'8(7(7'7(;)8'6)5(7(9(5(8)8(4'8)	
VB8)Θ\ӕ_ϗ\ϗ\Ϙ_ї\��ZpQ0]E-cF+dF+]E/bH*aF,_F,aF,bF.bF.aG)_F,bG-cE,cF+*.A@>�e?Ϙ_җ_ϖ^З_З_�wMB45(9)7'8)7(7'8'7)5(8(_E-ϖ^җ_З_ϖ^З_З_aF,!<82 
�xLҗ_Ϙ_И]З`ї\Жb�yJ 1/+	�zKΘ\җ_�pD
	 3o"y#v!eN 5 %і^ї\ѕ_ϗ\ϖ^і^E1 7<9  :  	�yJϕaϗ\Ҕ^ϖ^і^ÍX ommmpw�oYH@:889;<==@@DIUf�"�)�(,�+!� �q`S
G;655;BEG		E
EB???>>	>	<96356999        999     r	o	lg

aZU	T
Q		O
N	M	L	O		O		OPPQQ	R

S	SS		R
	R
Q

SR		R	V
Z	
]b	g

k
p
s
v
w
xyzyt
m	  �pFϙ\њ]Й`К]њ]К^  	[P><:7779:<=?AA?AAABC	TZC7'љ^И]К]ϙ]љ^њ]mQ2-30..,+++,,+**%&5B??>>,;(К^З_Λ]њ]З_ј`И]И]љ^љ^И]К^К^Й`ј`К^љ^Й`Й`К^И]К]Й`Й``H*53
�zK͙]Й`ҙ\Κ^К^ϙ]�{K4 20,% 	�qDҘ]Иa�yJ
8	ylS< *%aF+ϖ_Ζ[Ε^Ζ_Җ`_F,=996 7 ?0
8'і^ϖ_ϖ_Ζ[Ε^ѕ_  plmpu||sd
RE?;:;;;<	=	=>>B	IV
h�"�".�/1�0&�$�r[
K
?: 88	<
CJJKHD	D	CB
>	=<	;853	24498:       9:8     v	to
h

b	[
VRO
N
N	M
K	LNPQ		R

S
	R	S	S	S		R	QPPQ	Q	R	
S
	X	
\	cg
m	qt	w
xz
z
xv
s	m�qDϞ`К]ӛ`ћ_Н_ћ^  	X	TP	NLMNO	Q	S
U
VXXWX	X
X	X	YXY
YB5+͜^қ^ћ^Ҝ`Ҝ_͝]bK+0[Y
VS	RQQPONMKGHD@?=>>>;D3 ��Sќ]ћ^Ҝ_ћ^ћ^ќ]ќ]ћ^Ҝ_ћ^ќ]ҝ^ќ]Ҝ_Ҝ]�tD�}Iћ^Ϝ]ћ^Ҝ_К^aI- 8-�|LΛ]Н_ћ_Ӝ_Н^ҝ^[ 31/,'%!  	 �i>ќ]Н^đYE4H\C3(%  �e?і^җ_ѕ_ј[ϖ^	=:	424 7CX�xMЗ_җ_ԗ_ї\ϖ_  uqsuy{{sfWLB?<;;:;:<<==BHTc�!� /�-4�1(�&�k
S

D
>><=C	H	IGFED	DCA?=:7333443999        9:8     y	to	fc]	X	TQNLL
K	LNPQ		R

SRQ
Q	Q	Q	Q		O	O	OQQ	TY]	b

h	ot	w
yz
z
w
v	
t	
rm�uE̟\Ҡ^џ]ϟ]ў`ϟ_  VQPOPRRRS	T
VWW
W
U		UXYTV	
WW	[E7,͞`ϟ_Ҡ^Ϟ`͟_ϟ]aH.1	\
YWUVUTQOLJI
IEA@@==@??=" 	 8+6)7*6)6*6*6)6)6*7+8)6*7+ �uGџ]ϟ]ϟ_͠]ϟ_bJ. 7- *!8*7+5+9+6*7+9,+ 630-* $" ! 9+9)6+8*E	8/ &%�oHЙ`ϙ]И]И]�qD  ; 62/48J	cAsR1Й`њ]ϙ\К]К^ xuuxywsj^QIC?
<:99:;=>@>@DN]�!�-�)4�1*�*�j
P	
D
@	ABF	I
I
G	ECDDDB@<:73333334999        9:8     xr	mf	c	^	Z	
U	QNMNMNN	P	P	
P		R
	R
P	P	O
N	N	O
P	O
P	R	
U	ZZ	^g
ow
wxvs
srr
p

o�xFϢ^Ϣ^ͣ\ͣ^ͤ[Σ` 	S
QR	STW
W
V	U	U
U	
U	
U	
T	T
	U	U	T
W	X	[	[	c	J7+ͣ^ϣ\Ϣ^Σ`Τ_Ϣ^eL*2^\YVVURPMJIH
F	CBB?B?@?>?@>8/.////0013878C�xFФ]͢_Ѣ^Τ_У_aL- ;?1//.1/..0:4.)&$ $ "#$$-&
2		:?	K	B0/&% 
�rEќ]М`ϛ_ԛc`I)50014=V
qScH-ќ]Ҝ`Н_ќ]Κ^ yzxywrkbXP		K
D@	=;::;=<	=	=;<@	JZx�&�$.�+'�%|g
V
LG
G	IHFDCBACCC?=7542332257999        9:8     u
o	k
eb
_
[
	URQ

P	ON	N	
P
P
P

P	OOON	N	O
O
O
PQ
SS

V	X
Y\	ckr	tuts
r	r	s
s
t�{DΥ\ͧ_ϧ_Ѥ`ϥ^ϥ^  W	
VX	X		X		Y	Y	X
W	U
VU	U		T	T	TU	
U	X	\
_efK
5-ϥ^Х\ϥ^Φ^ͥ]Χ\bM-3_
	[Y	US	ROMJH
GG
G	GF	F	DBA?@BCBDABBBBBEFGIKO
LLH �{EШ]ϥ^̦^Φ^Ц_aM*#>CFEDBCC@>;51/%#"#"% % #*4?N	R
	H
9	-(( ( �vDР`ϟ]Р`ў_`K,///0	8	Fb!SaJ*Ҡ^ў_ϟ_џ]�uE"}xvwsmf_XRN
IC	@	??	=<<<<<9;>	H
Uj~�"�!"� xk	`
	W
RNJ	FCA@?@@A?<74233344469999        9:8      p

lh		c	
a		^
Z	WSQ
Q	PO
N	NN
O		O	
NNP	OO	O
P	
P	
P	Q

UU	
VWY\_f	los
t	v	u
u
tt	t	'�q?Ѫ_̩_Ϩ]Щ_Щ^̩_
/3010....---,-0/0*2^	h	hX+"Ш]Ѫ`Щ^Ϊ^ҨaΪ\jY2.210.,+)((''''&(! %=ADGGFC@BBDEEGILLLJJH E �}EΨ`ѩ^ͩ]ѩ^Ш]dP-%EI	HIECCDB >7 3 . * ) ( %$""!#)1=CF	@2	(%%'aK/ϡa΢[ѣ\̡^{b6 )  +.0<Qo!�#,
�wEϢ_ϣ\ϣ\Ϣ^pU3=}wtsnida\WTO
JGFC@>;;:99;?G
O]
i
ptywr
j^WQF	BA?AA	BA><744233113679888        999     k	
h	eb
`\	Y
V	S	P
NQ	O		LK
JL
N		O	Q	Q	
SRQ
Q
UU	STUTU	X
Z	]
b

ej	
n
rwyyw
w
s
EOF%̫bέ^Э]έ^Ь`ϫ]��SdQ,bP+cQ,^P,`P,^P,^P,`P,`P,`P+`P+`P+`P+cQ,]O+aQ,_O*n]2�~F\P,9j	l
n��S̫\ͫ_έ^ͬ]έ^��Zm\1`P,aR+aN+^P,`P+`P,`P,`P,`P,`P,^P,^P,`P+aQ-bP+p]2�}D^P,%EEGGGDDDEEFGIKLKIGDA=  �Gϫ]̭^έ^έ]έ^`P,'K HFGG	GBA?:2.+()))%!!  % ,5	:	=	;.# "%'")"ϥ^Τ_Τ]Ϥa��P ,,/2CY
v!� Τ_ͥ]Τ]ѥ^Τ]E7 Vzxtrmiec`[XS
POK
	E@>	<9878;	@	E	I
P
U^gsxvpd\
S
I	CBBBBB?;84 344	542279	:9999        :9;   d	a`a		^	ZW	US		O	M
N	LJ
JK
M
O	Q	S
RTUU
S	S
T
SR		R
	R
TU	W		[_ei	n
	r	x{{y
ws
o	��Iͮ_ΰ_ͯ^ͯ\Ͱ_ͯ^ΰ_̯^̰\ΰ_Ϯ_Ϯ^Ϯ^Ϯ^Ϯ^ͯ^ΰ_ͮ_ͮ_ͯ^ͱ]ͯ^ί`ͯ\ͯ\6/Nm	nr>E:б\̯^Я_ΰ_ΰ_Я_̯^ϰ[Ϯ_ί`ͯ^ΰ_ͯ^ͯ^ͯ^ͯ^ͯ\ͯ\ͯ^ΰ_̯^Ϯ^ΰ_̮_:/:
LMIHHHGF	GIJKMMKHE@@>;��Kΰ_ͯ\Ѯ^̯^ͮ__Q-)HHGGGFC>:510---+'" " &*0

5
	74+#$$' )�{DЩ_Ϩ^ͨ^ѩ^:,+38G
ZvDcM*ͨ^ϩ[Ц_Ϩ^��P�{upokihhfca_\XQ
L
EA;9898	:<==AG
Saq{}uk`
TL
FABBB@<7334345657;;86999        9:8     `	`
]		[	X	URPNMLJI	I	LN	
P	Q

S
S	R

TUTS
R		R		R		R		R
Q		R		S	U	Y	^	glrtwzyxwt
t		GaQ-��JϮ^ͯ`ΰ_ΰ]ϯ\ΰ_ΰ_ͱ]ͱ]ͱ]ͯ\ΰ_Ͱ_Ͱ_ΰ_ͯ^ΰ_ΰ_Ͱ_ΰ_ͯ^ΰ]˱]

jruyv	2*!�w>��XͰ_ΰ_ΰ]ΰ]ΰ]ΰ_ΰ_ΰ_̯^Ͱ_Ͱ_ΰ]ΰ]ΰ]ΰ_ΰ]Я_ΰ]ΰ]Я_ΰ]MOOKKLLJKMMMLKIEA=;<< ;̮]ϱ`ΰ_Я_ΰ]ΰ]aQ,( KJHGGEA;643443.)%!   !&	+
/	12/+&%&(')"��XΪ^ϫ]Ω_��R
5=J	Y	6'#��X̫\ˬ]Щ_ͫ_8-G~ytqnmlmnpppnkd
YR	H@;87:97545:D
P	_o|~xmcT
NDB@A?;633343557:;:942999        999      	^	
\	
YW	R	N
KIII	I	IILO
QR	R	RRRRSSSRQ
Q

S	R
P
	R
	S	U
Z^	glr
s	uvyzx{
|
~vC                                                       /
x	y	yy
|
w
Y&                                                      $RQPLLNOOOOPNKGB?>=;:=A              FKLIGD?;8667863.)#!  %*-	.00-'&% '(%TD'��W̬`ѭ_ͬ\��J9. $ 7/ Zά`έ^̭^ҭ]TE%
8
ywsrqpquz��|yl\R	I	E?<8	965446;BK	Zky}znc
	WSJD?:642235667:;<	:8522:::        :::      	[W	W	SL	I	IHHH
J	J
N	Q
R	R	U	TS
RR	QR	TTSRRQ
PRS
S
	X	]
cgjp
r	tvy	}~�����
}
xo	i
c	^	[
W
T
S
	T
T
U	W	
YZ	[
\		^	
`e	g
m	rv
z
{��
�z
vs	m
ifda	a
b
a
`^[WUTUX	Z\\WYY	TRONOQRRR	R	PPKFB>====>AE	FHJIII
LJJMLGD?;;<:;;840,)%#!!#"%)-131.*'$$%%' &$��R̯^ͮ_Ͳ\ͭa��Jn]2m]3��Kͮ_Ϯ_Ͳ\ͮ_¢YPE'8	zwsusux|���!�!� ��s`WN		IF?	:632257<B	JWiy~~rgZ
S
J	C	;9545564569>@>9621/888        :::     	UQ
Q	M	IHIJKM	O	N	Q
RQ
Q
RRQ
Q
Q
Q
Q

S
SQ
Q
P
P	
P	
P	S

S
V
[

_
d
hmquy���	����
~	y	v	n

h	
`[X	V	V	U
U	U	
U		X	
YZ		[
\	]	c	f
ko	t{�	�
��~		z
t	
oo		ljhff	d
b	`
]
ZVUUWZ
]^\Z
XWRTSRVXX	VTPKJEB?==>@EEFHHIHIHKLNNKFC?=	<=??><73.-,*%# "#$%).143/*$!!"$&$TE$��Jΰ_ΰ]ΰ_ͱ]ΰ]ί`ͯ\Ͱ_äYxi8=�}{wwux|���!� &�#+�))�(#�#�~i_UPG
	@	7300279=BG	Vi
|"�!� xl]	U		H
>	65335447;;>?><9620-9:8      999     MLJHIH	IKM	OQ	Q	QR	Q
Q
RQ

P	Q
Q
RS
S
R	R	R	R
P	
P	
P	R	
S
V

Y

\	
agou
|������
��{w
r	je	`	[WVW
V
VW	W	W		X	XZ	]

ab
i

m
u
|�	
�	��
|
y	
vsonnm	k
h
c_]	[ZZ\\]_`^\X	UTTUXY[\YUPJGDA?>@BBEGIFGIII IKKKLJE@??ABBA@=:5 20//+($"$$'+03550(#  !"$$$	$( 	F;_R,`T,_R,bR-aQ,9-
/c{}}|z}{��"�$�!'�$(�&-�)2�/0�0)�(#��xk]QD<3//149=?BDR	
i�!�!%�%�p]PB;7667656<EGDA<9742.+9:8      999     HG	G		H
I	K
NO
P
	R

SQ
	R
	R
R	S
S
R	
P	Q
QQ
P	P	R	Q
Q
Q
QRRS

S

UY
	^
b
hr{��������	~{
up
f
a]Z	
Y
W
Y
X	
VW	V
W	W	W	Z	^
din

s
z���	�

|
x
w
v	r
t	sqn
id`]\\_
b
c
b
b
ba\W	U
V	TY]\	\YSNJEDA@AAEGHIHHHGEIJL	NMKH D@ =
?BFHE@<97 4321.,(&"#$(,1585	.	)%" " !#&% $*(+& $)0Iksx|����� �$� '�$+�',�+.�,1�02�22�3-�-&�#��s\	K
<710028=>?@A
P	j	�#�")�$�oVG;	:999899	=DKLGB<:62/+'999        98:    HH
H
J	
M
M

P

RUVUQPPP
P

P
	O	NNONN	N	
P

OPO
R
R
S
U	V
X\`emu|�������	�{upl
h
	c
	^
\[
[
Z
X	X	W	W	
Y
	[		[]
afjt{~��
���
}
|yxus
o	ki	d	a`	`	ac	e	d
b
b	a_
\	ZZX	
\	]^	[W	RLH	EBABD
F	
G
HI	J	I	IHGJLKL	M	NJC	?@@A@	DDB@;98686520-)&%$%',3
9	=:	4

,($"!%%$%%'),.
4	
;@
FP]eow� ����"� (�$*�&-�)/�,0�-0�-/�.1�/2�/-�+*�'#�!}gP		C	7412469=<<<=Pm�'�%+�'j	T	G
>	<
8		435;B	GK
M
IEA=	:4.*(&799        888     	IJ	L	M
PQ	Q
TUU
S	QOO

P

P
O		O	
NNO
O	P	PP	O
P
PRSUX
X
[
_dko
w|����
�
�}
yusrnid	`	^	\[	X	W

U	
U	V
Z]]

`d
jqwy
|	�
�
�	�
	��
~	yt
qmg	g	
d
fffgg	hda	a
aa	`
_	^	`\[	ZUOKID@@CHIJ	I
KL	LJLJKN NOOKIDCBAAC	FCA?==;<::76331+&$#%(,	4	=	
A	@	
;	2-(#"$$(&'(),/57?D
MVbju}���� � )�'*�'+�)-�*,�)+�*(�(*�(.�(,�*)�(&�"�n[
	F;54347	:;=:8 6	8Kl�%�"$�"|hU	
J	A

>	866:BJN	L		J
IFB>81,((% ,..        666    KN
MOP
	Q	QRRRQ

P		O	OOOP	OOON	O	O		O		O	
P
Q
RSUXY[
]ad
jpv{������}{yvqm	h	ea	^	Z	
Y	X		VW	W	Y[^	a	f	i
nptx{	~	�	����
�
�



z
xs	pljj	k	kj	kihfdbcdfgf
c^YTPJHDCBDFGKMMNOOOOMLNQPMJGAAABDFGGE@;;>@?>;98641,)&$& +,	9	
D	KHA70+*'&&'&&'(+-15<CK
	U`jt�� �"�!�$�#*�).�,,�++�*)�'(�%'�$(�%(�%(�'#� �u[K>875689997 557	:Kk�%�#$�"xfVLB< 7 6 9BKPNMLHG@93,)%'.         444    N	
NPO
PPO
N	O
Q
Q

P	Q

P	NNP	P		O	O	O		O	
P
QQRTUUXZ\\^`ci
ov{����}{zvqm	f	c	
_
]
[
Z	X
WZ[\	^	a	f	jmpqs
w
{~�����
�	�
|

w

t	
s
rpo	n
l
l
lk	jhfefh	h	i
gf`[S
LHFFFFGKLMOPRRQQPQPP	QOLHEBAC	EH	IHECA@@?@A??;:;862,(&$'+-;KUSI	<
3-+&&&'&%&')+1	5:	
A
JU`mw ��%�#)�&)�&)�&,�'.�,.�**�''�"$�!#� %�#'�%$�!�q^MC
;
9	53687743349	>Pl�$�"%�$xgUH	=9 8= B
J		OROMMLD<3-)%#)	8         222     M

N
P

P
O
O
O
	O	OQ
	R
Q	Q
Q

P		OQ

P		O
P		P
P	Q
	R

STUWXZ\^^`b
ejnu{������}z
y	u	pn	g
e	a	^	
\	
\
Z	Z	[]
`cfhklnos
w
|
�
�
�
�
�
�	�}	{	w
u	ss
r
rp
o
o
o	lk	jiii	j	i	g	a^	Y
TNIFIKMONMNO	RRSSSSSRTROLHEEEHIKKJFA?ACEEB?=; : ;;961+'$$ $ (	.>
Sa^S
D
8/*('%%$$%%')03:	B	KTao|"� "�$�#)�&*�)+�**�**�)+�&)�#%� #�!�"�  �}jZ
P
GA;:7433222346	;	?O	j
�!�#%�%}jR	C	99=H	N
QOOQQP
LC9/+' & *4

B          >=?"""    	LOMN	L
M
N	MN	O	O	ON	
P

P

P

P
N	N	N	Q		R

S
S

UWXZXY[\_acf	i
otx~����	�
|zws	pm	i
	gc`^]	^		^
_
_`aeg
k
lqtx}��	�

�	}
|y
x
w
xwt
s
r	qoo	j		j		k	k
l	kj	
i
`[YUQLFDIKNOPQS	TVVVVVWWUQNJGEEHKMLKJIFDDADEEA><; ==<950+'"!" $.B	\lj]L>3-'$%#""##$&/3	:BLWgw�!�"�!'�$*�'*�)(�))�('�&&�$$�"%�  ���wgVK
	D@><;8520/268:9;=M
f�'�#)�) {eL=7
<D	OPPPQQNLG<1(' ' * 2CO           VXXMMM"$$                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         qprsss```555                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               +*,***     ���������usrSUUB@@577453444444244244244444444444444444444444444444444444444444444444444444444444524635435435444444444555244244444444444444444333253253444444444444444444453453444444444444435435444444435435435444444444453453453444444444444444444444444444444444453453444444444444444444444444333444444444444444444444644444444444444444444444444555444333444444444333644644444444444444444644453453444244244244444453643643644444444244244244444244245444444644444444444444444444444444444555444444444244444453244444444444444435435444444333444444444444444444444444444444444453453444644435244444444453444444435435444253253444444444453453644643453444444643453244253444444644644444244253444453643644444444244045253444444244244444444453444444444453453444444444453564643644435879A@BLKM\\\cccVUW666    ���������������yyyyyyywwxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxwwwxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxzxxzxxxwyxxxxxxxywxxxxxxxxxxxxxwyxwyxwyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxywxxxxxxxxxxxxxxxvxxvxxxxxxxxxxxxxxxxxxxxxxxwwwxxxxxxxxxxxxxxxxxxxxxzxxxywxxxxxxxxxxxxxxxxxxxxxxywxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxywxywxxxxwywwwxxxxxxxxxxxxxxxxxxwwwxwyxwywwwxxxxxxxxxxxxxwyvxxvxxxxxxxxxxxxxxxxxxxxzxxxxxxxxxywxywxxxxxxvxxxwyxxxxxxxywxxxxxxxxxyyyxxxxywvywvxxzxxzxxxwyxxxxxxxxxxxxxxxxxxxxxxxxvxxxxxxxxxxxxxxxxxxxxxxxxxxvywxxxzxxxwyxxxxxxxxxxxxzxxzxxxywvywxxxxwyxxxuytzwyxxxxxxxxxzxxxxxwwwxwyvxxxxxxxxxxxxxxxxxyyyvxxxxxxxxxxxvxxxxxxxxxxx{yyxxxxxxxwyvxxvywzwyzwyxywxxxxxxxxxxxxxxxzwyxwyvxxxxxxwyxwyxywwxvyxzyxzxxxyyyxxxxwyxwyvxxwyy{{{�����qqqYYY999  X�      �� ���    0	        (     D                         xxyyyyyyyyyyyyyyyyyyyyxxyyyxyyxxyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyzzyzzyzzyzzyyyzzyzzzyzzzzzyzyzzzzzzyzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz{zz{zzzzzzzzz{{z{{z{zzz{z{z{{z{{z{{{{{{{z{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{|{{{{{{||||{{{{{||{|{{{{{{|{{{{||||||{||{|||||||||||||||||||||||||||||||||||||||||||||||||||||||oooYYY[[[mmm|||||}|||}||}||}|}}|}}}|}}}}}}}}}|}}}}}}}}}}}}}~}}}}}}}}}}}}}}}}}}~}}}}}}}}}}}}}~}}}~~}}~~}}~}~~~~}~~}~~~~~~~~~~~~~~~~~~~~~~~~ccc111jjj~~~~~~~~~~~~~~~~~~~~~~~~~~~~��������������������������������������������������������������������������������������������������������������������������������������������������zz{{{{{{{{{{{{{{{{{{z{zz{{{z{{zz{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{|{{{{{{{{{{{{|{{{{|{{|{{{{{|{{|{{{|{{||{||{{|{{|{{{{|{|{||{||{|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||}}}||||||}||}|}}|||}||}}|}|}|}||}|||}|}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}~}}~}}~}~}}~~}~~}~}~~~~~~~~~~~}~~~~~~~~~~~~~~~~~~~~}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~aaaBBB===***yyy~~~~~~~~~~~~~~~~~~~~~~~~~~~�~������������������������������������xyyBBB888yyy������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������}}|||||||}||||}||||}|}}}}|}}|||}|||}}}|||}}}|}}|}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}~~}}~}~~~~~}~~}~~~}}}}}}}~~~}~~}~~~~~~}~~~~~~~}~}}~}~~~~~~~~~~~~~~~~~~~~~~~~~~~������������������������������������������{{{TTT///$$$"""222JJJ%%%%%%GGGxxx���ooo&&&������~~~EEDSTSvvv000+++   mmm```###(((^^^888eeeJJJMMMFFFPPP~~~~~~~~~~~~������������������iii...���aba)))(((VVVwww000rrr������ppp222www������jjj,,,UUU&&&,,,999zz{bbbccc```'('&&&UVU|}|///:::<<<(((%%%GGHppp,,,???a`a>>>ggg...$$$555pppnnn+++���lmm,,,������///###666srs���_^_%%%+++eee***ppp���())qrrlmm---opo.//+++%%%RRRbbb???EEE000###HHH...fffGGG%%%...eeeiii:::||}SSS'''+++aaa������������������������������������������~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������YYY%%%^^^|||ZZYnnnvvvklk%%%ddd���ggg������~~~434NNNZZZ***lmm\\[&&&\\\sssMMM'''bbb888GGG555JJJ~~~||||||~~���������������������\]]"""{|| !!bbbgggggg   qrq������ooo!!!sss������^^^444KKKNNO+++xwwDDE;;;~~~kkkCCC***^__sss   aaa999;;;bbc*))zyy]]]---$$$MMM}|}LLL222]]^���aaa   ������ono444PPP���������[[[///}}}������fff���hhha`a!!!JJK444zzz000AAA^^^---PPPVVVvvv!!!rrrXXX...yyy\\\   ddd())zzz}}}mmm888111������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������:::KKK���WWW������^^^ggg���iii&&&555hhh555PPPNNN333���XXX   ttt���%%%NNN(((ddd999GGG���555JJJ}}}{{{|||{{{yyy~���������������^__###utu~~~���^^^   lll������qqq


"""???vvv```!!!ccc222,-,uuu###HHH   bbb)))777iiibbb���WWW,,,===ddd***|||___...ddd���hhh'''YYY���bbb!!!���������tss)))cdc������]]]-.-z{z������ggg���jjibbb"""GGG===���BBBCCB```...XXX(((uuu|||QQQ===���rrrfff,+,|||kjj(((777qqq������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������FFFGGG������������lll***$%%WWW������lll���MNN !!666RRRTUU444���lmmIII556JJJWWW,,,ggh@@@!!!LMM&&&\]\}}}{{{uvv4CH/?>LKNOwww���������LLLjjj@AA:::???333yzy#$$(((```���ttt###uuu@@@===_``###pqqVVV878LMLVVV())���/00))),,,VVVdddRRRfff___SSS///```EEE[[[bbb223LMM222RRR00/PQPlmlIHH655AAA������������rss"""������_``,,,CDC~~;;;CCC!!!DDD677DDDIJJDCC���DDDIJIccc0/0iijVVVDDD566iiiXXXccc222OOO<<<@@@jjj777UUV333VVVmnn������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������_``)))������������@AAABB|}}���������noo���opp788TTT{{{lll���ccd������bcc___\]]}~~kll��stt___YZZdee|}}~~~|}}^__;K ~� ��g�;KQ|~}������LMMijj��`aa___~���hiicddooo���www#$${||jjj/00Z[[$$$~~~^_^aba���qqqlmm���tuuhiiiii[\\rssYZZdeeoppZ[[ggg���BCCYYZ~opp���ghhZZZggg������```bcb___���������yzzz{{pqq!!!������abb222���������cddeeeZ[[stthii\]^���vwwwxx���tuuy{{eee011uuu_``_``~nooVWW~zzz]]]ddd������dee`aa���ggg]]]{||���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������FFF666fggeffhiiPQQ677klleff������tttmnnCCC000<<<VWW������������������������������___������������������mmm%9@a� ������Nbghg���������\\\���������������������������z{{_``444IJJhii%%%���������������������������������������uvv������������������}~~���|}}cdd������������������������������������mnn233...lmm������eee)))mnmxxx���������������������������������������hii444���������������z{z���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������defLMMMNN{|}���_aaKMLfhh���������Y[[JKKRSS|~~moovww������������������������������eff���������������������MQR	Kcj� ������	h�NRS���������cddJKK������������������������������MNNKLL\]]������^__���������������������������������������������������������������������ijj��������������������������������������������������������LMMLMMSTT������������������������������������������kll���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������svv2>Trx� ��������&AK|}}������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������SXZ<P^ �� �� ������8Jopp���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������xzz)=COj�� �� �� ������SoWYZ~�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������8CGLe|� �� �� �� ��������$)+IJJ?@@/00&&&&&&&''&''&'''''&&&$$$...9::CDD_``~��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������IJJIJJIJJIJJIJJIJJIJJIJJIJJIJJIJJIJJIJJIJJIJJIJKIKKIJKIJJIKJIKKIKKIKKIKKIKKIKKIKKIKKIKKIJJIJJIKKIKKIKKIKKIKKIKKIKKIKKIKKIKKJKKIKKJKKJKKIKKJKKJKKJKKJKKJKKJKKJKKJKKJKKJKKJKKJKKJKKIKKIKKIKKIKKIKKIKKJLLJLLJLLJLLJLLJLLJLLJLLJLLKLLJLLJLLJLLJLLKLLKLLJLLJLLJLLJLLKLLKLLKLLKLLJLLJLLJLLJLLJLLJLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLKLLLLLKLLKLLKLLKLMKMLKMLLMMLMMLLLKLLIJJGHHDEECCC;?@9Gd� �� �� �� �� �� ������(2-..???UUUooo������������������pppTTT===)))(((455:;;@AAGGGIIJJKKKLLLMMLMMLMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNMMMNMMNMNNMNMMNMMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMNNMOOMOOMOOMOOMONMOOMOOMOOMOOMOOMOOMOOMOOMOOMOOMOOMOOMOOMOONOONOONOOMOONOONOONOONOONOONOONOONOONOONOONOONOONOONOONOONOO������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������~��wzznpp*:?@V|� �� �� �� �� �� ������e�]]]�����������������������������Ķ�����������jkk566OQQtvv������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������v|����������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������z{|.5Ur �� �������� �� ��������NZ_�����������������������������������������ʻ��������EEE'((788kml������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������#:Bg� ���������� �� ��������*[l������������������������������������������������������zzz454>>?������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������vv����������������������������������������������������������������������������������������sss]]]qrrqqqFFFmmm������{{{������z{{���������������������������������������������������������zz{zzzwwwWWWTTTvvvWWWYYZ������������������������������������������wxx���OPPVVVPPPppq~~ssswxxnooWXX[\\aaaSSSUUUuvv���������������������������������������������������������������������������������������������������������jll8J }� ����
��]w5Q\ |� �� ������h���������������������������������������������������������ı�����333"""cdd���������������������������������������������������������������������������������������������npp���������������������������������������������������������opp~�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������uvvHIIRSSTTT���333`aaPQQ666VWWHIIttt[\\;<<nnneff������������aaaSSSqrrtttXXX���������������������}~~``aPPQPPP???������QRRYZZ;<<VVVZ[[```\\\`aalll\]]������������������WXXgggPPP@@@���QQQ]]]OOOSTTGGGBBB������~~~xxx[[[fffMMMSSSjkkbccjjjyzz������������������������������������������������������������������������������������HLMQm ����
��t�JSV���Wo �� ��������G^f��������������������������������������������������������Ⱥ�����FFFWWW���������������������������������������������������������������������������}~~\\]eee_``444���ggg������������������������������������������[[[IJJxxxFFF���]]]������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������hhiqrrUUU���???FGGaaa>>>FFF|||���aaa��������???444[[[yzzGHHMMM[\[������HHHghhmmm���������������oooDDD@@@+++��л��888yyynnn;;;PQQ������kkk��޴��;;;UUUlmm������������������EEEyyy;::VUUKKKzzzUUUzzz������EEE������,,,GGGfff___RRR������[[[ttt���ZZZ�����������������������������������������������������������������������������������*13i� ������4OY������agir� �� ������AS��������������������������������������������������������������ä��\]]FGG������������������������������������������������������������������mmmcddXYY�����ꃃ�/00���nnn���������������������������������uuuqqqUVV������kkk$$$���dddlmm���abb___������dee������������������������������������������������������������������������������������������������������������������������������������������������������������VVV;;;PQPQQQOOOTTTKKK�����ӯ�������������㎎�GHHSSSoooAAAttt���<<<jjj���---������}}~������]]]STT=>>������>>>������uuu�����������������𑑑������SSSJJJsss```||}dddz{{������rrr---UUU222������������������GGG���������������������������lll***VVViiiNNN\]]lll������������������������������������������������������������������������WWW'- |���
��Wl��������쿿� M^ �� ������x�}}}��������������������������������������������������������������ű��fff$$$HII������������������������������������������������������������lmm������555���������MMM=>>VWWjkk���������������������������fgg���~~~%%%������ooo,--...mmmhhhJKK������fffZZZpqq~�����������������������������������������������������������������������������������XX�������������������������������������������������������������������|{{fffJJJ010FFF���������������������������333���������������{{{RRRrrr///DDD������ooo\\\ooojjjuuuVUUzzzCCCRRR���XXX���������������������������ggg��������ֽ��������UUUiii���������abbooo��ۥ����������������������������������������������������ݯ�������ꈈ�ggg���mmn������������������������������������������������������������������aaa2226E ������PWZ������������luy\} ��������=EH�����������������������������������������������������������������Ū��dddZ[[���������������������������������������������������������``a������000jjj��������Ŗ��������UUU������������������LLMRRR\\\������,,,:::�����֞����������顡����������rrr���������������������������������������������������������������������������������������������������������������������������������������������������������uvv[\\UUU�����̾��������������������NNN������������������������{{{QQQ�����ʫ�����������:::PQPz{zxxx***,,,MMM�����������������������������������������������������ղ��fggttt___XXX���\]\www��橩�ddd�����������������������������������񣣣���������������������MMMjkk���������������������������������������������������������������rrr:::222Up��	�� BO������������������%M\�� ������[r��������������������������������������������������������������������ů��dddiji���������������������������������������������������������IJJGGGLMM���������������������MMM���������������fff���;;;bbbYYY���~~~��������������������������쇇�OPPKKKnnn\\\���������������������������������������������������������������������������������������������������������������������������������������������yyyXXXuuu\\\������������������ggg���������������������������TTT�����������������������􈈈rrr���xxxmmm@@@������������������������������������������������������ttt���������www���TTT|||EEEttt�����������������������������������������������������������������ۅ��������fff������������������������������������������������������������LLLSSSILNu���`�mtw������������������t|c� ��������ruv��������������������������������������������������������������������æ��GGG,,,���������������������������������������������������������XXX���������������������{{{cccXXX���������������vvv&&&:::DDD������������������������������ZZZ������������uuu������������������������������������������������������������������������������������������������������������������������������������������������nnncdcfff���qqq��������𨨨�����������������������㱱�kkk���������������������������lll������RRRutuLKLCCCbbb���������������������������������������������ccc������������������jjjYYYHHH���}}}HHH�����������������������������������似�������������������������������������qqq���������������������������������������������������������[[[EEE������0^nh�Q`f���������������������1P[�� ������;_l��������������������������������������������������������������������̻�����)/1 +/2;)JV�����������������������������������½�����������bbb���������������������aaa������lll������������]^^������������������������������������������������������YYYrrrYXX������������������������������������������������������������������������������������������������������������������������������������������VVVkkkEEE������������������������������tttXXXsss}}}KKK������������������������������������rrrcccppp���HHH��������������������������≉�������YYXTTT���WWW���������������������ZZZ���[[[NNNGGG��������������������̠��������lll������bbb������GGG���������������������{{{vvvddd���������������������������������������������������www<<<}}|��������˄�����������������������������}}}a� ������]x����������������������������������������������������������������������9Wc4B	 (IPR���������������������������������������������������WWW|||���iii���������������������lll������nmn]]]OOO��������������������ҋ��������vvv������������������������kkk���~~~sss������������������������������������������������������������������������������������������������������������������������������������eeeCCCPPP�����������������������꟟�WWWdddLLLnnnqqq���444���aaattt��������������������Ϧ��QQQ���ccc///KKK������������������������vvvlll���������===���������������������������|||FEEeffFFF���������������������������]]]SSSddd~~~aaabbbeeennn���������������������������www�����������������������������������»��������������WWWUUU���������������������������������������������8F �� ����{�drw�����������������������������������������������������������ӆ��8U`Vl$FR]gk@AA+/0puw��������������������������������������ü�����������KKK��������������������䁁�ppp���������lll���222�����������õ��������kkk��������Ȝ��������|||���������������������ccc�����������������������������������������������������������������������η�������������������������������������������¾�����������uuvTTT��Ǔ��������������������ZZZ+++hhhDDDyyyzzzgggcccYYYllm\\\888SSS���������������������hhhmmm|||>>>ccc�����������������ﶶ����VVV}}}���������������fffRRR<<<:::���������������������bbb999SSSOOOTTT������������������oookkkaaa���������������yyyJJJ�����������������������������������������������������������������ü�����������BBB������������������������������������������������dqvd� ������BQ��������������������������������������������������ݪ��fv|I]k�VlCT[���t~�,JU+:3DYgl�����������������������������������ƾ��������[[[������������������������fffhhhnnn������WWW222*++mmm���������������������bbb���yyy>>>III�����������������������ѣ��\\\���������������������������������������������������������������������������������������������������������������������������������qqqYYY��􇇇���������������������OOO���PPP������������������vvv```���GGG���������������������������&&&kkk������������������FFF���iii���������������������tttPPPNNN������������������ppp***���xxx������������������������hhhsss��������������ɶ�����ssswwwFFF������������������������ggg\\\��������������������������������ļ�����������fffZZZ���������������������������������������������������Qf ������	\z��������������������������������������������ޙ��P]b[tv�����f�Qem3LU1<2C\|+:mw{�����������������������������������ƾ�����gggZZZXXX��������ͥ�����������XXX���|||~}~���pppzzz���������������������������[[\zzz������OOO���������������������HHH���ttt��������������������������������������������������������������������������������������������������������������������ƿ��������������III@@@mmm���������������������???mmm���������{{{���������xxxXXX+++LLLPPP������������������hhhJJJggg���fffKKKIIIHHH������NNN���sss���������������ttt���ffflll***QQQ�����𹹹���������WWW��ǀ�����JJJ���������������������TTT���������������������������___������������������������������{{{fff��������������������������Ż�����������QQQ������������������������������������������������������`lqj� ������PSU��������������������������������׾�����(KX`�������
�� GUAHK8EBZb�[{). cnr�����������������������������������ǿ��������z{zmmnyyy������������������hhhhhhccc������WWW���������������������ZZZEEEiii�����ƾ�����LKK��²��ppp���������������������bbb������������������������������������������������������������������������������������������������������������������������������YYY,,,���������������������uuuccc�����ƾ��������hhh���sssSSS```GGG���������������������������IIIpppvvv���yyy{{{���OOO������SSSoooUUU������lllsss���```TTTVVVIII������������������������III]]]SSSlll���������������������WWW��������������������ǹ�����yzz```ccceee�����������������������������������������������������ż��������yyyMMM���������������������������������������������������������Sg ������*N[��������������������������̒��Tdj!Rd_�������l�(Zl/69.P\Vqc� v�Nk<F'KY3D,7y|}������������������������������������������___]]]���������������������]]]������������___�����흝�������������YYY������ppp�����ķ�����<<<IIIZZZ���������������������ooo��������������������������������������������������������������������ڴ�����������������������������������������������������]]]���<<<���������������������CCC���nno������������dddXXX+++�����脄�������uuu���������������������^^^tttqqq���gggmmmuuuVVVGGGwww���kkk===���EEEXXX]]]???|||^^^���������������������������VVV���\\\���������������������nnnsssHHH������������������������������;;;������������������������\\\ddd�����������������������������Ž��������hhhggg���������������������������������������������������������V\^z� ����q�}~~��������������ҹ��owz+FPWru�������Ni%@JDV\)JVWrCY^��a�AY	d�AY7I+2��������������������������������������î��ggg�����ƃ�����������qqqooo���ppp|||������������]]]�����⿿�������������rrr���yyy�����ɽ�����PPP���������������������CCC;;;VVV��������������������������������������������������������������������������������������������������������������������ĵ�����___zzz;;;jjj������������������]]]���xxx�����´�����nnn���+++���������������������������������������pop������������eee���~~~jjj===ttt]]]FFFQQQ���vvv���������������������������������������aaammmnnn��ן�����������������������ooo��������������������ƴ�����???�����ڨ����������������������������������������������������ƽ��������ZZZ�����������������������������������������������������������趶�CW ������L`g������������MahDV[| ~� �� ������D]	8IOjd�`�Ur������y�x�F]+Q_CLO'''��������������������������������������Ǵ��ttt������;;;���������������������RRR������bbbUUUooo���������������������www��������������®��QQQ��������������������튊�������kkk�����������������������������������������������������������������ߓ����������������������������������������������Ǹ�����{{{;;;aaa���������������������vvu�����������Ÿ�����hhh���WWWWWW��������������������������嗗����hhhccc������������kkkEEEqqq@@@///@@@fff������������������������vvv���������������������������hhh���VUUeee������������������������}}}��������������������ʹ�����wwwMMMhhhttt������������������zzz�����������������������������Ǿ�����rrrXXX���������������������������������������������������������������H[bp�����!Xl���ikl3GNSlg� �� �� �� ������ q� |� �� ������������{�]|HV]jo������...��������������������������������������˽�����\\\LLLsss���������������������LLL���nno������kkk������������������rrrnnn��������������Ƿ��wwwOOOgggggg���������������������JJJ�����������������������������������������������������������������ᑑ���������������������������������������������̾�����qqq��������������������Ͳ�����RRR��������������ú��ooo999MMM������������������������������TTT������]]]������������bbbVVVOOOaaa��ı����������򻻻������ppp���������������������������UUUJJJPPP������KKK���������������������***GGG�����������������������˻��������bbb������������������wwwUUU]]]������������������������������������```[[\��������������������������٘��cv}3Zh��������������������������ݤ��K_����y�F_j� � �� �� �� �� �� ���� �� �� ������������f�az7LT��������Ŀ�����CCC}~}������������������������������������������lll���������������������MMM]]]ppp���ooo������???�����������迿�������[[[��������������˾�����ttt���������������������hhh<<<hhh�������������������������������������������������������������������������������������������������������������������ð��WWW���www���������������������������������������xxx��������������������������Е�����������������bbb���������|||___������������������������^^^������������������������������������iii���sssqqq���WWW��������泳����������>>>���zzz��������������������̻��������aaa���������������������������ccc�����������������������������¼��VVVddd������������������������uwxH^x�f�nx|������������������������wxx<H~� �� �� �� �� �� �� �� �� �� �� �� ������������	��Zy)Udatz�����������������̨��VVVnnn��������������������������������������Ŝ��fff�����箮������������㔔���Ĩ��zzz���[[[999VVV���������������������iii������������������������������������������333}}}��������������������������������������������������������������������碢������������������������������������������������ɷ�����^^^nnn���������������������ggg�����������������՘��{{{���YYY������|||RRR�����󞞞������|||VVV???xxx���wwwNNN666vvv���������������~~~������������������������������������@@@mmm���ppp���kkk������wwwNNN������������������ddd���|||��������������������ʹ��������[[[\\\������������������������PPP�����������������������������ľ��PPPiii��������������������ܥ��$L[t�����Xcg��������������ˢ��Uaf!DP\yu� �� �� �� �� �� �� �� �� �� ��������������
��e�0HQ|�������������������������Ү��ccceee��������������������������������������ɶ��ttt===tttnnn�����������������黻�ttt���iii���������������������������\\\�����������������Ħ��UUU������www�����������������ú��vvv�����������������������������������������������������������������������������������������������������������������ν�����SSS���������������������IIIvvveee�����������������Ѝ��FFFJJJIII������YYY������[[[kkkdddVVV���[[[JJJ���YYY������;;;���������������������������������������������888www��򓓓]]]���yyy���������mmmWWWXXX������������������jjj��������������������������ȶ�����XXX:::���������������������bbbYYY___���������������������������������MMMmmm�����������������ܸ��<NU\} ������?NS�����٫��u{}?ZdF]f� �� �� �� �� �� �� �� �� �� �� ��������������o�)[mXae��������������������������������Ѱ��jjjbbb��������������������������������������ɻ�����kkk���������������������}}}mmm������```���������������������uuu������hhh��������������ħ��___���������������������fff��������������������������������������������������������������������������������������������������������������������������Ĭ��jjj�����파�������������������}}}���������������������aaa���===rrr���nnnxxx_`_www���VVVhhh���GGGLLL���mmmAA@===CCC���������������������������qqqrrr���000aaa��茋�GFF���KKK������������������sss���ppp�����������������􉉉��������������������������ű��]]]���������������������������VVVxxx������������������������������������LLLppp��������������۫��:T]	Pj �� ������7HM���NVY M^^~q� �� �� �� �� �� �� �� �� �� ��������������
��Tn1OZy����������������������������������������ѱ��mmmccc��������������������������������������Ǭ��qqq������������������������tttccc[[[������fff���AAA���������������������WWW�����������И��LLLPPP~~~�����������������򅅅�����������������������������������������������������������������������������������������������������������������������������̶�����CCC��������������������˗��::9��������������������ࡡ�\]]������mnnvvv���fffEEE���xxx^^^�����ĵ�����|||XXX������������������������```ppppppdddlll��׍��XYY���IHI���___^^^��������������ġ��kkkyyy"""���������������������PPP���������������������������mmm{{{jjj���������������������EEE}}}���������������������������������LLLjjj�����������۽��<NU\} �� �� ������OfYyu� �� �� �� �� �� �� �� �� �� �� �� ������������s�*SaX]_�����������������������������������������������ϯ��iiifff�����������������������������������˾�����{{{III���������������������QQQ������������aaa��������������������헗�������������������jji���}}}JJJ���������������������ZZZJJJ�����������������������������������������������������������������������������������������������������������������������Ӡ��EEE���������������������YYY���~~~�����������������������ɽ�����aaaIII~~~yyy222QQQiiiooo|||ooouuuLLLCCC|||������������������sss������kkk��ņ��lllaaaddd���VVVuuuqqq888���ttt�����Ś��������NNN������������������������kkk��������������������ʹ��������FGFwww������������������������������������������������������������OOOccc��������ܾ��dknOg }� �� �� ������ �� �� �� �� �� �� �� �� �� ��������������	��	��Rk;Ze��������������������������������������������������������̫��ccclll�����������������������������������ü�����eeeWWW���������������������SSS������������www���������������������JJJSSRwwv�����������ά��jjjQQQ888���������������������TTT������������������������������������������������������������������������������������������������������������������������܏��ZZZZZZ�����ܢ�������������������怀���������������������ǻ��������XXXBBBVVVZZZ������vvv������jjj���>>>```;;;�����������������􎎎��ơ��[[[TTTvvv������������OOO���ccbDDDEEEaaaiiinnn���jjj���aaa���������������������YYY���UUU�����������������̿�����sss[[[rrr������������������}}}[[[���������������������������������������XXXXXX�����Ǆ��7JQ\{|� �� �� �� �� �� �� �� �� �� �� �� �� �� �������������� ����k�?MR��������������������������������������������������������������̧��TTT{{{������������������cccjjj���������yyy���___���������������������������[[[������ccc```ccc���������������������ZZZ������zzy��������Ѿ��RRRoooooo���������������������ZZZ�����������������������������������������������������������������������������������������������������������������������������̢�����LLL���������������������oooggg�����������������¹��������pppJJJ������������������\\\qqq]\]������`aa:::���������������������^^^SSS���������������������\\\```}}}ooo���������|||���]]]���xxxhhh���lll���������������������jjj�����������Ŧ��������\\\ggg[[[������������������������|||������������������������������������cccMMM���^hlE\j� �� �� �� �� �� �� �� �� �� �� �� �� ������������	����]uHX������S`e��������������������������������������������������������������Σ��AAA��������������������Լ�����������}}}���cccuuu��������������������������ϧ��iii�����ƹ�����LLL���������������������```www�����������ҽ��PPP���������������������\\\���sss�����������������������������������������������������������������������������������������������������������������������������ݸ��___VVV���������������������������yyyttteee���������xxx���mmm|||LLL������������������@@@������������ggg�����������˪�����gggAAA}}}kkk������������XXX:::$$$������������������@@@HHHUUU������]]]vvv��������������������镕�qpquvvFFFXXX���RRRhhh���AAA;;;FFF��������������������Ǥ��������������������������������������������yyyPPP{{{6Ao� �� �� �� �� �� �� �� �� �� �� �� ������������	��q�HXRbi������]y����GU��������������������������������������������������������������Ν��111���������������������|||������VVV���������:::������qqq���������������������ZZZ������\\\MNN{{{��������������������������������������ӿ��\\\������iii������������������VVV������������������������������������������������������������������gg������������������������������������������������������╕�ssseeemmm���������������������������RRRZZZfffqqqkkk���;;;������(((��������ګ�����������������ooo������qqqVVV������������������\\\|||TTTpppnnn```QQQyyy��������������������ӷ��zzz���___ffg���NNN���������������������KKK���qqq&&&��񂂂wwwXXXCCC\\\```���������������������������~~~qqq��������������������������������������գ��bbbppp���;NTo� �� �� �� �� �� �� �� ������������	��
��_w>NT���������������8IO ����s���������������������������������������������������������������ń��;;;���������������������LLL������OOOkkk��в��]]]��������������������������̻��eee��ܝ��������lll���������hhh���������WWW���xxx���������������@@@�����������������������˶��eee�����������������������������������������������������������������������������������������������������������������������������๹����UUU���������������������������|||������]]]~~~���%%%GGG���������������������������cccWXX�����ʊ��777SSS������������������~~~---���kkkooo��ܜ�����������lll��������������ꥥ�,,,~~~kkk���aaa��������ʮ��������������������HHHooo\\\888[[[��������������������������ٛ�����jjj�����������������������������������������ٿ��rrqUUV���U`dc� �� �� �� �� ������������	��	��`�!N^gsx���������������������djmm�����MVY��������������������������������������������������������ֳ��eeeccc���������������������bbb������HHHTTT���������������������������������222mmmfff������ccchihiji������������������������|||��������ؽ��}}}qqq������������������������cccqqq�����������������������������������������������������������������������������������������������������������������������������������ᥥ�nnn���������������������������������������KKK�����������������������������Ⱦ��VVV������������xxx���������������������������������������������fff������������������������������������������OOO��������������������������퉉����������������������������������������QQQ������VVV��������������������������������������������ɋ��EEEDIKCX {� �� �� ��������������{� VjIQU�����������������������������캻�
BW ����b{��������������������������������������������������������ԟ��BBB���������������������������eeettt������������������������������������������������~~~��ؿ��|||cccuuu������������������]]]������������gfg���HHHsss������������������yyybbb~~~ccc��������������������������������������������������������������������������������������������������������������������������������虙����~~~hhh111hhh���������������������������������������������������������IIIppp��������������蓓�fffiii]]]���������������������������kkk��������������������������𝝝vvvtuu���������}~}jjjhhh������������������������������������������������```���������������������������qqq��������������������������������������������ұ��QQQ5Bk� �� �� ������������d�4[iruv���������������������������������������2P[����	w�u|~������������������������������������������������������}}};;;��������������������奥����VVV�����������������듓���������������������������ӝ�������✜����������������������������SSShhh���SRSuuuuuu```===���������������������000mmm�����������������������������������������������������������������������������������������������������������������������������������������콽�YYY���XXX��������⸸�������������������������������������jjj������bbb�������������������������]]]��������������������Ѭ����������������������������ҹ�����kkkZZZ��������᫪�~~~���vvv��������؄�����������������������������rrr���������������������������kkk���������������������������������������������������������:GKc� �� �� ������	����WoDW^�����������������������������������������������耈�^~����1We��������������������������������������������������ظ��IIIeee���������������������lllOOOsss������nnnttt������>>>������������������������fff}}}�����Ꞟ�xxx���666������������������������@@@www\\\���999���������������������������uuu������������������������������������������������������������������������������������������������������������������������������������������������XXX���TTT������uuu���������������������������[[[���������������qqq������������������������888bbbmmm��ʮ�����������������������������������������qqqfff���|||lll{{{��������ԋ��oopQQQRRQ���������������������������������������������������������wwwZZZ```���������������������������������������������������������kopPg �� ��������L_V[]������������������������������������������������������)Wg����So��������������������������������������������������ϋ��444������������������������uuu�����҇��sss������iii������������������������������kkkooommm�����ࠠ�jjjrrrggg���������������������***eeejjjTTT�����������������������ē����������������������������������������������������������������������������������������������������������������������������������������������������������ñ�����ttt�����ג��������������������QQQ���������������ccceeeZZZ���������������������������������uuuKKKIII�����������������򲲲������ppp���������;;;���fff������������������JJJjjj:::������������������zzz������zzz�����������������爈�eee```HHH���uuuyyy������������������������������������������������������������PWYMg ����
��x�eee������������������������������������������������������������cknw�����blo�����⨬�x����������������������������������ڴ��HHH^^^��������������������������������������ׂ�����jjj������[[[�������������������JJJ���ddd���������uuu{{{eee��������������������ߞ��������������������������������ooo555iii���������������������������������������������������������������������������������������������������������������������������������������������������������HHH���}}}���xxx}}}eeeUUU###������___������iiicccnnn���������������������������������������������������TTT^^^������XXXhhhlllQQQ���������hhh���qqq���������������������������```���kkk�����ŏ��```]]]YYYKKK������iii��ţ��RRRhhhYYYzzz������������}}}��������������������������������������������������������������毯�.FOw�g�Oa;MT��������������������������������������������������������������걱�Nb����DR���)KXE]c|���������������������������������rrr---�����������������������������������������߇�����OOO\\\���~~~������������������```���������������������GGG���������NNN��������������������𞞞������jjj������������===���~~~�����������������������������������������������������������������������������������������������������������������������������������������������������������䪪������Ѩ��www���FFF������ddd�����������ׇ��zzz��������������������������������������������І�����������������ccc���~~~fff���ddd���������������������������������������{{{���������������{{{���dddaaa���kkkrrr��������ܘ�����jjj���jjjjjj������������������������������������������������������������������������s|2;GJK������������������������������������������������������������������������6IP������J\Us��,_r�����������������������������ؗ��666|||�����������������������������������������������������͆��yyy��������������������������������������󻻻������ppp��������������������������ض��@@@��������⛛����������eee������������������������������������������������������������������������������������������������������������������������������������������������������������������������������ZZZddd������������������������������������������������������������������������������������������������lllvvv������������������������������������������������������������������ccc�����ବ�������������������yyyrrr������������������������������������������������������������������������������������kkk777�����������������������������������������������������������������������倇�Yx �� ��������_x��������������������������ܳ��<<<OOO��������������������������������������������������������σ�����ppp������^^^���ppp���```��������������������ĥ��������������������������YYY���������������������������xxx���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������HHHJJJ��������������������������������������������������������������������羿�AS �� �� ������_z�����������������������ݺ��XXX999���������������������������������������������������������������������lllXXX}}}ggg[[[��􇇇���������������������+++���aaa���|||\\\|||������MMM������������������nnn��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������뤤�CCC^^^���������������������������������������������������������������������?Xbp� �� ����	��^w������������������������ggg...�����������������������������������������������������������������������旗�������XXXhhhUUUlll��������������������ᶶ������ɠ��ddd���YYY������vvv���������fffuuuvvv�����񳳳��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������갰�DDDTTT������������������������������������������������������������������D\di� �� ����	��\s�����������������ݼ��[[[333���������������������������������������������������������������������mmm������hhhnnn���������������������������������������������zzzxxx^^^������[[[���QQQhhh������]]]zzz�����������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������먨�777FFF���������������������������������������������������������������lx|\} �� ����	��)Xj��������������ڪ��TTT111�����������������������������������������������������������������������������������������������������������������������������������디������ޯ�������������Љ�����������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������VVV===�����������������������������������������������������������ꞟ�Sj �� ����
��)Wh�����������׈��===FFF��������������������������������������������������������������������������������������������������������������������������������������������������������������񮮮���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������xxx---QQQ���������������������������������������������������������5Ua�� ����	��3S_�����ڮ��hhh+++eee��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������䚚�RRR===nnn���������������������������������������������������ptvh� ����	��6MV���ppp999EEE��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������ْ��QQQ>>>ddd��������������������������������������������ݾ��$JX ����	��,4222LLL��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������̙��bbb999BBBggg�����������������������������������ѹ��IQS_���	��3;rrr�����������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������俿����zzz[[[TTTSSSXXXbbbiiijjjjjjjjjddd[[[MMMRRRPPP$EQ����BV]�����������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������Ʌ��{�b�uxy���������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������?o�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������p      �� ��'    0	         ��        � Ȑ- �����    H a c k s   C o n f i g u r a t i o n    � M S   S h e l l   D l g              P� 2     ��� �x�[              P  � � ������� �Ock              P� 	 � � ������� �c��              P      ��� �bE�R�                P % #    ��� �N��cj~:              � P3 $      ���             2  PN $ 
  �  m s c t l s _ u p d o w n 3 2                PW S , 
 �  ��� �f�Ock             PW F , 
 �  ��� OP�y�Ock             P 8 A 
   ��� �od�Wb_gQ�}              X � �  ������� kub�	gOUL��Q(u, �S�� �bўO\b4xW               !P'  , ?   ���              P F @ 
   ��� �rΑwk��!hck             PW 8 = 
 2  ��� �N�/���U�t           � P� �    3  ���             �  P� �   4  m s c t l s _ u p d o w n 3 2                  P\ � $  5  ��� }t�}X[:                P � 4 
 6  ��� aIQ�^�Ock                P�  � �   ��� T E X T _ G O E S _ H E R E              P S B 
   ��� �Oeu'`C R C �Ock             PW o B 
 K  ��� 2 D �b8O�Ock             PW | B 
 L  ��� �b8ON��}�Ock             P a B 
   ��� A l p h a !jg               PW a : 
   ��� ܕ��C R C �Ock                P\  %     ��� T C   O f f s e t   X               �  P�  #  #  ���             �  P�    "  m s c t l s _ u p d o w n 3 2               �  P� $ #  %  ���             �  P� $   $  m s c t l s _ u p d o w n 3 2                 P\ % %  !  ��� T C   O f f s e t   Y                P o D 
 '  ��� N V I D I A o�aS�Ock             P � 2  7  ��� P R I M C L A S S :            � P@ �   8  ���             �  PO �   9  m s c t l s _ u p d o w n 3 2                P � 4  :  ��� F B M S K :            � P@ �   ;  ���             �  PP �   <  m s c t l s _ u p d o w n 3 2                P � 4  =  ��� P S M :            � P@ �   >  ���             �  PO �   ?  m s c t l s _ u p d o w n 3 2                Pf � A 
 @  ��� _U(u�}X[�qu�             Pf � A 
 B  ��� _U(uP S M �qu�               Pe � A  M  ��� NZPA l p h a ,nf�                P � � W ,  ��� 2����Ock             P } D 
 N  ��� �N��m�^�cj~    �      �� ��'    0	         ��        � Ȑ     <�     S h a d e   B o o s t   S e t t i n g s    � M S   S h e l l   D l g            Pl 2     ��� �x�[              P l 2    ��� ͑n              P  ._ ������� r�i_��te              P  "  ������� ���T�^               P7  �    m s c t l s _ t r a c k b a r 3 2                 P 2 "  ������� �N�^             P7 0 �    m s c t l s _ t r a c k b a r 3 2                 P K   ������� \�k�^               P7 H �    m s c t l s _ t r a c k b a r 3 2                P      ��� 1 5 0                P 2     ��� 1 5 0                P K     ��� 1 5 0       
      �� ���    0	         ��        � Ȑ: ����x�     -�n. . .    � M S   S h e l l   D l g               P  � * �  ��� ���              P  � , �  ��� ���              P I %  ������� ㉐g�^:              !PG G H } �  ���               P X "  ������� 2n�ghV:              !PG V o v �  ���               P g 5  ������� ��L��c�c  ( F 5 ) :              !PG e o b �  ���               P v <  ������� kub��k�O  ( F 6 ) :              !PG t o b �  ���              P� � 2     ��� �x�[              P� 2     ��� �S�m            # P� I $ 
 �  ��� ���zS                P � <  ������� D 3 D gQ�㉐g�^:              � PR � #  �  ���             �  Pn �   �  m s c t l s _ u p d o w n 3 2              � Px � #  �  ���             �  P� �   �  m s c t l s _ u p d o w n 3 2              � PQ � #  E  ���             �  Pn �   C  m s c t l s _ u p d o w n 3 2              � Px � #  F  ���             �  P� �   D  m s c t l s _ u p d o w n 3 2                !PQ � K 
 G  ���               P � * 
 ������� ؚn!hck:                P � - 
 J  ��� ��teؚn             P{ � ! 
 �  ��� �S�Y             !PR � J b �  ���               P � <  ������� bO(u�|�x�k�O:               P � c  ������� bO(uP S 2 �S�Y㉐g�^  :                P � � g ������� D 3 D   �X7_  ( �S��_w�Ee��)                 P� � P  ������� M�Y2n�g�}z:              � P� #  �  ���             �  P4�   �  m s c t l s _ u p d o w n 3 2                P� m C 
 �  ��� }tN��o             Pn : 
 �  ��� \xeZ                P� } N 
 �  ��� AQ1�8 MOCQ}t               P} U 
 �  ��� �f�S��Ock( F B A )                P� � ] 
 �  ��� ���}�bE�R�  ( A A 1 )                P�  O 
   ��� _U(uS h a d e   B o o s t                 P W  
  ��� -��[. . .                P� � � * ������� ߎ�N!j_-��[             P� _ � = ������� lx�N!j_-��[             P� � G 
   ��� ��_Ulx�N�Ock              P� W    ��� M�n. . .                 P :   ������� E��RhV:              !PG 8 o }   ���              P� / � . ������� C u t i e r�i__�d              !P� H <  -  ���               P� L &  ������� o�:y!j_:                 P� ;   ������� �N�^:              � P� 9   .  ���               P;   ������� ���T�^:            � PI9   /  ���              P6K , 
 1  ��� gQ��o�             !PG 8 o }   ���              P�  P 
 &  ��� ��_UF X A A              P P 
 (  ��� ��_UF X   s h a d e r                P� ! P 
 H  ��� ��_UC u s t o m   s h a d e r       �      �� ���    0	         ��        � Ȑ
     G     �q_-�n   � M S   S h e l l   D l g          � P  �  �  ���               P�  2  �  ��� p��. . .                !P  � z �  ���               P�  2  �  ��� -��[. . .                 P 2   ������� :\�[:              � P /   �  ���            � P@ /   �  ���               P� / 2     ��� �S�m             P� / 2     ��� �x�[             Pf / 0   �  ���     �      �� ���    0	         ��        � Ȑ ����� �     S e t t i n g s . . .    � M S   S h e l l   D l g               P  � , �  ��� ���              P ; %  ������� ㉐g�^:              !PP 9 f } �  ���               P J "  ������� 2n�ghV:              !PP H f v �  ���               P Z @  ������� }tN��o  ( D e l ) :                !PP W f b �  ���               P i 4  ������� Cf�R  ( E n d ) :                !PP f f b �  ���               P x D  ������� ؚ�[�k�O  ( P g D n ) :              !PP u f b �  ���               P � F  ������� M�Y2n�g�}z:              � PP � #  �  ���             �  Pl �   �  m s c t l s _ u p d o w n 3 2                P, � 2     ��� �x�[              Pa � 2     ��� �S�m              P  � * �  ��� ���              P � @  ������� gQ�㉐g�^:              !PP � f b �  ���              P� � 1 
 �  ��� ���zS               P � F 
   ��� ��_US h a d e   B o o s t                 Pm � W  
  ��� -��[. . .                P � R  &  ��� ��_UF X A A   ( P g U p )                Po � U  (  ��� ��_UF X   s h a d e r   ( H o m e )              P � d  H  ��� ��_UC u s t o m   s h a d e r   ( B a c k )              Po � U  I  ��� ��_U�W�vTek    �	      �� ��'    0	         ��        � Ȑ8 ����x�     S e t t i n g s . . .    � M S   S h e l l   D l g               P  � * �  ��� ���             P� � 2     ��� �x�[              P H "  ������� 2n�ghV:              !PF F o v �  ���               P W 5  ������� ��L��c�c  ( F 5 ) :              !PF U o b �  ���               P
 � A  ������� ꁚ[�㉐g�^:              � P\ � #  �  ���             �  Px �   �  m s c t l s _ u p d o w n 3 2              � P� � #  �  ���             �  P� �   �  m s c t l s _ u p d o w n 3 2              � P\ � #  E  ���             �  Px �   C  m s c t l s _ u p d o w n 3 2              � P� � #  F  ���             �  P� �   D  m s c t l s _ u p d o w n 3 2                !P] � G 
 G  ���               P
 � ( 
 ������� ؚn!hck:                P
 � - 
 J  ��� ��teؚn             P\ � ! 
 �  ��� �S�Y              P� � P  ������� M�Y2n�g�}z:              � P� #  �  ���             �  P9�   �  m s c t l s _ u p d o w n 3 2                !P\ � J b �  ���               P	 � <  ������� bO(u�|�x�k�O:               P
 � P  ������� P S 2 �S�Y㉐g�^  :              P� � ] 
 �  ��� ���}�bE�R�  ( A A 1 )                 P� 2     ��� �S�m              P  � , �  ��� ���             P { � e ������� D 3 D gQ萞X7_  ( �S��_w�Ee��)              P� � � 2 ������� ߎ�N!j_-��[             P� c � H ������� lx�N!j_-��[             Pp : 
 �  ��� \xeZ                P� W 
 �  ��� �f�S��Ock( F B A )                P� � R 
 �  ��� AQ1�8 MOCQ}t               P� p C 
 �  ��� }tN��o             P�  O 
   ��� _U(uS h a d e   B o o s t                 P K  
  ��� -��[. . .                P� � G 
   ��� ��_Ulx�N�Ock              P� K    ��� M�n. . .                 P 9   ������� E��RhV:              !PF 7 o v   ���              P� 0 � . ������� C u t i e r�i__�d               !P� K 1  -  ���               P� N .  ������� o�:y!j_:                 P� <   ������� �N�^:              � P� ; (  .  ���               P< %  ������� ���T�^:            � P?; (  /  ���              P2O 5 
 1  ��� gQ��o�             P�  P 
 &  ��� ��_UF X A A              P P 
 (  ��� ��_UF X   S h a d e r                P� # P 
 H  ��� ��_UC u s t o m   s h a d e r                P� ~ M  )  ��� TTpu'`N��o             !P{ #  *  ���               P e 4  ������� O p e n C L   E��R:              !PF c o v +  ���     X      �� ��     0 	        X4   V S _ V E R S I O N _ I N F O     ���      	     	                            �   S t r i n g F i l e I n f o   �   0 4 0 9 0 4 E 4   L   C o m m e n t s   h t t p : / / g u l i v e r k l i . s f . n e t /   .   C o m p a n y N a m e     G a b e s t     `   F i l e D e s c r i p t i o n     G S   p l u g i n   f o r   p s 2   e m u l a t o r s   6   F i l e V e r s i o n     1 ,   0 ,   1 ,   9     2 	  I n t e r n a l N a m e   G S d x . d l l     � 6  L e g a l C o p y r i g h t   C o p y r i g h t   ( c )   2 0 0 7 - 2 0 0 8   G a b e s t .     A l l   r i g h t s   r e s e r v e d .   : 	  O r i g i n a l F i l e n a m e   G S d x . d l l     *   P r o d u c t N a m e     G S d x     :   P r o d u c t V e r s i o n   1 ,   0 ,   1 ,   9     D    V a r F i l e I n f o     $    T r a n s l a t i o n     	�