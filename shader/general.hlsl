/********************************/
/* Vertex Shader Output Structs */
/********************************/

struct VOut1
{
	float4 p	: POSITION;
	float2 uv	: TEXCOORD0;
};

struct VOut2
{
	float4 p    : POSITION;
	float2 uv   : TEXCOORD0;
	float4 wp   : TEXCOORD1;
};

struct VOut3
{
	float4 p		: POSITION;
	float2 uv		: TEXCOORD3;
	float2 uvnoise	: TEXCOORD0;
	float4 pproj	: TEXCOORD1;
};

struct VOut4 
{
	float4 p		: POSITION;
	float3 uvw		: TEXCOORD0;
	float3 normal	: TEXCOORD1;
	float3 vVec		: TEXCOORD2;
};

/********************************/
/*        VERTEX SHADERS        */
/********************************/

VOut1 ambient_vs(
	float4 p : POSITION,
	float2 uv : TEXCOORD0,
	uniform float4x4 wvpMat,
	uniform float4x4 texMat)
{
	VOut1 OUT;

	OUT.p  = mul(wvpMat, p);
	OUT.uv = mul(texMat, float4(uv, 0, 1)).xy;

	return OUT;
}

VOut2 diffuse_vs(
	float4 p : POSITION,
	float2 uv : TEXCOORD0,
	uniform float4x4 wvpMat,
	uniform float4x4 texMat,
	uniform float4x4 wMat)
{
	VOut2 OUT;

	OUT.p  = mul(wvpMat, p);
	OUT.uv = mul(texMat, float4(uv, 0, 1)).xy;
	OUT.wp = mul(wMat, p);

	return OUT;
}

VOut3 invisible_vs(
	float4 p : POSITION,
	float2 uv : TEXCOORD0,
	uniform float4x4 wvpMat,
	uniform float4x4 texMat,
	uniform float timeVal)
{
	VOut3 OUT;

	const float4x4 SCALEMAT = float4x4(
		0.5,  0.0, 0.0, 0.5,
		0.0, -0.5, 0.0, 0.5,
		0.0,  0.0, 0.5, 0.5,
		0.0,  0.0, 0.0, 1.0);

	OUT.p		= mul(wvpMat, p);
	OUT.uv		= mul(texMat, float4(uv, 0, 1)).xy;
	OUT.pproj	= mul(SCALEMAT, OUT.p);
	OUT.uvnoise = uv + timeVal;
	
	return OUT;
}

VOut4 water_vs(
	float4 p: POSITION,
	float3 normal : NORMAL,
	uniform float4x4 wvpMat,
	uniform float2 waveSpeed,
	uniform float time_0_X,
	uniform float3 eyePos)
{
	VOut4 OUT;

	const float NOISESPEED = 0.1;
	const float3 SCALE = float3(0.012, 0.005, 0.03);

	OUT.p      = mul(wvpMat, p);
	OUT.uvw	   = p.xyz * SCALE;
	OUT.uvw.xz += waveSpeed * time_0_X;
	OUT.uvw.y  += OUT.uvw.z + NOISESPEED * time_0_X;
	OUT.vVec   = p.xyz - eyePos;
	OUT.normal = normal;

	return OUT;
}

/********************************/
/*        PIXEL SHADERS         */
/********************************/

float4 ambient_ps(
	VOut1 vsout,
	uniform float3 ambient,
	uniform float4 colormodifier,
	uniform sampler2D diffusetex : TEXUNIT0) : COLOR0
{
	return tex2D(diffusetex, vsout.uv) * float4(
		ambient[0] * colormodifier[0],
		ambient[1] * colormodifier[1],
		ambient[2] * colormodifier[2],		
		colormodifier[3]);
}

float4 diffuse_ps(
	VOut2 vsout,
	uniform float3 lightCol,
	uniform float4 lightPos,
	uniform float4 lightAtt,
	uniform float4 colormodifier,
	uniform sampler2D diffusetex : TEXUNIT0) : COLOR0
{  
	float lightDist       = length(lightPos.xyz - vsout.wp.xyz) / lightAtt.r;
	float lightScale      = 1.0 - (lightDist * lightDist);
	float4 diffuseTex     = tex2D(diffusetex, vsout.uv);
	float3 diffuseContrib = lightCol * diffuseTex.rgb * lightScale;

	return float4(
		diffuseContrib[0] * colormodifier[0],
		diffuseContrib[1] * colormodifier[1],
		diffuseContrib[2] * colormodifier[2],
		diffuseTex.a * colormodifier[3]);
}

float4 invisible_ps(
	VOut3 vsout,
	uniform sampler2D diffusetex : TEXUNIT0,
	uniform sampler2D noisetex : TEXUNIT1,
	uniform sampler2D refracttex : TEXUNIT2) : COLOR0
{	
	float4 diffuseTex = tex2D(diffusetex, vsout.uv);
	
	if (diffuseTex.a > 0.0)
	{
		float3 noisen = (tex2D(noisetex, (vsout.uvnoise * 0.2)).rgb - 0.5).rbg * 0.05;
		float2 final  = (vsout.pproj.xy / vsout.pproj.w) + noisen.xz;

		return tex2D(refracttex, final);
	}	
	else
	{
		return diffuseTex;
	}
}

float4 water_ps(
	VOut4 vsout,
	uniform float3 ambient,
	uniform sampler2D noisetex : TEXUNIT0,
	uniform sampler2D diffusetex : TEXUNIT1) : COLOR0
{
	float3 noisy = tex2D(noisetex, vsout.uvw.xy).xyz;
	float3 bump = 2 * noisy - 1;
   
	bump.xz *= 0.15;
	bump.y = 0.8 * abs(bump.y) + 0.2;
	bump = normalize(vsout.normal + bump);

	float3 normView = normalize(vsout.vVec);
	float3 reflVec = reflect(normView, bump);
   
	reflVec.z = -reflVec.z;
   
	float4 reflcol = tex2D(diffusetex, reflVec); 

	ambient = ambient + float3(0.01, 0.01, 0.01);
   
	return float4(ambient, 0) * reflcol;
}
