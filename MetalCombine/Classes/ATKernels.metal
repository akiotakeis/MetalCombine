//
//  ATKernels.metal
//  MetalCombine
//
//  Created by Akio Takei on 2017/12/23.
//

#include <metal_stdlib>
using namespace metal;

kernel void combineHorizontal(texture2d<float, access::write> outTexture [[texture(0)]],
                              const array<texture2d<float>, 10> inTextures [[texture(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
    
    uint width = inTextures[0].get_width();
    int num = gid.x / width;
    float4 colorAtPixel = inTextures[num].read(uint2(gid.x - width * num, gid.y));
    float4 rgbaColor = float4(colorAtPixel.r, colorAtPixel.g, colorAtPixel.b, colorAtPixel.a);
    outTexture.write(rgbaColor, gid);
}

kernel void combineVertical(texture2d<float, access::write> outTexture [[texture(0)]],
                            const array<texture2d<float>, 30> inTextures [[texture(1)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    uint height = inTextures[0].get_height();
    int num = gid.y / height;
    float4 colorAtPixel = inTextures[num].read(uint2(gid.x, gid.y - height * num));
    float4 rgbaColor = float4(colorAtPixel.r, colorAtPixel.g, colorAtPixel.b, colorAtPixel.a);
    outTexture.write(rgbaColor, gid);
}
