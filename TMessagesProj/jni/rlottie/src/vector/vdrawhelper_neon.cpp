#if defined(__ARM_NEON__) || defined(__ARM64_NEON__)

#include "vdrawhelper.h"

#if defined(RLOTTIE_USE_PIXMAN_NEON_ASM)
extern "C" void pixman_composite_src_n_8888_asm_neon(int32_t w, int32_t h,
                                                     uint32_t *dst,
                                                     int32_t   dst_stride,
                                                     uint32_t  src);

extern "C" void pixman_composite_over_n_8888_asm_neon(int32_t w, int32_t h,
                                                      uint32_t *dst,
                                                      int32_t   dst_stride,
                                                      uint32_t  src);
#else
extern void comp_func_solid_SourceOver(uint32_t *dest, int length, uint32_t color,
                                       uint32_t const_alpha);
#endif

void memfill32(uint32_t *dest, uint32_t value, int length)
{
#if defined(RLOTTIE_USE_PIXMAN_NEON_ASM)
    pixman_composite_src_n_8888_asm_neon(length, 1, dest, length, value);
#else
    for (int i = 0; i < length; ++i) dest[i] = value;
#endif
}

void comp_func_solid_SourceOver_neon(uint32_t *dest, int length, uint32_t color,
                                     uint32_t const_alpha)
{
#if defined(RLOTTIE_USE_PIXMAN_NEON_ASM)
    if (const_alpha != 255) color = BYTE_MUL(color, const_alpha);

    pixman_composite_over_n_8888_asm_neon(length, 1, dest, length, color);
#else
    comp_func_solid_SourceOver(dest, length, color, const_alpha);
#endif
}
#endif
