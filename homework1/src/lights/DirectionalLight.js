class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);
        this.lightPos = lightPos;
        this.focalPoint = focalPoint;
        this.lightUp = lightUp

        this.hasShadowMap = hasShadowMap;
        this.fbo = new FBO(gl);
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }

    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();
        //mat4.create()不会返回单位矩阵！！！！！！！！！！！！！！！！！！！！！！
        //所以我们在model transform时候需要将他设置为单位矩阵
        // Model transform
        mat4.identity(modelMatrix);
        mat4.translate(modelMatrix,modelMatrix,translate);
        mat4.scale(modelMatrix,modelMatrix,scale);
        // View transform
        mat4.lookAt(viewMatrix,this.lightPos,this.focalPoint,this.lightUp);
        // Projection transform
        const bound = 120;
        // out, left, right, bottom, top, near, far
        mat4.ortho(projectionMatrix, -bound, bound, -bound, bound, 0.01, 400);

        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);

        return lightMVP;
    }
}
