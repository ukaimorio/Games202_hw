#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 100
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define LSIZE 10.0
#define LWIDTH (LSIZE/240.0)
#define BLOKER_SIZE (LWIDTH/2.0)
#define MAX_PENUMBRA 0.5

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

float calcBias() {
  vec3 lightDir = normalize(uLightPos - vFragPos);
  vec3 normal = normalize(vNormal);
  float c = 0.005;
  float bias = max(c * (1.0 - dot(normal, lightDir)), c);
  return bias;
}
vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {
  // 定义常数和变量
  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );  // 角度步长
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );  // 采样点数量的倒数

  // 随机起始角度和半径
  float angle = rand_2to1( randomSeed ) * PI2;  // 随机生成起始角度
  float radius = INV_NUM_SAMPLES;  // 初始半径，保证点在单位圆内
  float radiusStep = radius;  // 半径增量

  // 生成Poisson Disk采样点
  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    // 使用极坐标计算点的位置，然后将其存储在poissonDisk数组中
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;  // 增加半径，以便下一个环的采样点更远
    angle += ANGLE_STEP;  // 增加角度，以确保均匀分布在圆周上
  }
}


void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
  float blocker=0.0;// 遮挡物计数
  float sum_depth=0.0; // 遮挡物深度总和 
  for (int i=0;i<BLOCKER_SEARCH_NUM_SAMPLES;i++)
  {
    vec2 uvoffset = BLOKER_SIZE * poissonDisk[i];
    float depth = unpack(texture2D(shadowMap,uv+uvoffset));
    // 判断当前点是否在遮挡物之后，如果是则计算深度总和和遮挡物计数
    float is_shadow;
    if(zReceiver<=depth+calcBias()+EPS) is_shadow=0.0;
    else is_shadow=1.0;
    sum_depth+=is_shadow*depth;
    blocker+=is_shadow;
  }
  // 步骤 3: 特殊处理边缘情况
  // 如果遮挡物计数接近采样数量，返回1.0表示完全遮挡
  if(blocker-float(BLOCKER_SEARCH_NUM_SAMPLES)<=EPS) return 1.0;
  // 如果没有遮挡物，返回0.0表示没有阴影
  if(blocker<=EPS) return 0.0;

	return sum_depth/blocker;
}

float PCF(sampler2D shadowMap, vec4 coords, float filterSize) {
  float block=0.0;
  for (int i = 0;i<NUM_SAMPLES;i++)
  {
    vec4 nCoords=vec4(coords.xy+filterSize*poissonDisk[i],coords.zw);
    float depth=unpack(texture2D(shadowMap,nCoords.xy));
    float cur_depth=nCoords.z;
    float vis;
    if(cur_depth<=depth+calcBias()+EPS) vis=1.0;
    else vis=0.0; 
    block+=vis;
  }
  return block/float(PCF_NUM_SAMPLES);
}

float PCSS(sampler2D shadowMap, vec4 coords){

  float zReceiver = coords.z; 
  // STEP 1: avgblocker depth
  float avgblockerdepth = findBlocker(shadowMap,coords.xy,zReceiver);
  //if(avgblockerdepth<=EPS) return 1.0;
  // STEP 2: penumbra size
  float dBlocker=avgblockerdepth,dReceiver=zReceiver-avgblockerdepth;
  float wPenumbra= float(LWIDTH) * dReceiver / dBlocker;
  // STEP 3: filtering
  return PCF(shadowMap,coords,wPenumbra);
}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  float depth = unpack(texture2D(shadowMap,shadowCoord.xy));
  float cur_depth = shadowCoord.z;
  return cur_depth>=(depth+EPS)?0.0:1.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {
  vec3 shadowCoord = (vPositionFromLight.xyz / vPositionFromLight.w) * 0.5 + 0.5;
  poissonDiskSamples(shadowCoord.xy);
  float visibility;
  //visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
  //visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0), 0.01);
  visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  //gl_FragColor = vec4(phongColor, 1.0);
}