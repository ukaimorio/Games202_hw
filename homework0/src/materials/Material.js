class Material {
  #flatten_uniforms;
  #flatten_attribs;
  #vsSrc;
  #fsSrc;
  // Uniforms is a map, attribs is a Array
  constructor(uniforms, attribs, vsSrc, fsSrc) {
    this.uniforms = uniforms;
    this.attribs = attribs;
    this.#vsSrc = vsSrc;
    this.#fsSrc = fsSrc;

    this.#flatten_uniforms = [
      "uModelViewMatrix",
      "uProjectionMatrix",
      "uCameraPos",
      "uLightPos",
    ];
    for (let k in uniforms) {
      this.#flatten_uniforms.push(k);
    }
    this.#flatten_attribs = attribs;
  }

  setMeshAttribs(extraAttribs) {
    for (let i = 0; i < extraAttribs.length; i++) {
      this.#flatten_attribs.push(extraAttribs[i]);
    }
  }

  compile(gl) {
    return new Shader(gl, this.#vsSrc, this.#fsSrc, {
      uniforms: this.#flatten_uniforms,
      attribs: this.#flatten_attribs,
    });
  }
}
class PhongMaterial extends Material {
  /**
   * Creates an instance of PhongMaterial.
   * @param {vec3f} color The material color
   * @param {Texture} colorMap The texture object of the material
   * @param {vec3f} specular The material specular coefficient
   * @param {float} intensity The light intensity
   * @memberof PhongMaterial
   */
  constructor(color, colorMap, specular, intensity) {
    let textureSample = 0;

    if (colorMap != null) {
      textureSample = 1;
      super(
        {
          uTextureSample: { type: "1i", value: textureSample },
          uSampler: { type: "texture", value: colorMap },
          uKd: { type: "3fv", value: color },
          uKs: { type: "3fv", value: specular },
          uLightIntensity: { type: "1f", value: intensity },
        },
        [],
        PhongVertexShader,
        PhongFragmentShader
      );
    } else {
      //console.log(color);
      super(
        {
          uTextureSample: { type: "1i", value: textureSample },

          uKd: { type: "3fv", value: color },
          uKs: { type: "3fv", value: specular },
          uLightIntensity: { type: "1f", value: intensity },
        },
        [],
        PhongVertexShader,
        PhongFragmentShader
      );
    }
  }
}
