/* ----------------------------------------------------------------------------
 *
 * (c) The GHC Team, 2014-2014
 *
 * Declarations for C fallback primitives implemented by 'ghc-prim' package.
 *
 * Do not #include this file directly: #include "Rts.h" instead.
 *
 * To understand the structure of the RTS headers, see the wiki:
 *   http://ghc.haskell.org/trac/ghc/wiki/Commentary/SourceTree/Includes
 *
 * -------------------------------------------------------------------------- */

#ifndef PRIM_H
#define PRIM_H

/* libraries/ghc-prim/cbits/atomic.c */
StgWord hs_atomic_add8(volatile StgWord8 *x, StgWord val);
StgWord hs_atomic_add16(volatile StgWord16 *x, StgWord val);
StgWord hs_atomic_add32(volatile StgWord32 *x, StgWord val);
StgWord64 hs_atomic_add64(volatile StgWord64 *x, StgWord64 val);
StgWord hs_atomic_sub8(volatile StgWord8 *x, StgWord val);
StgWord hs_atomic_sub16(volatile StgWord16 *x, StgWord val);
StgWord hs_atomic_sub32(volatile StgWord32 *x, StgWord val);
StgWord64 hs_atomic_sub64(volatile StgWord64 *x, StgWord64 val);
StgWord hs_atomic_and8(volatile StgWord8 *x, StgWord val);
StgWord hs_atomic_and16(volatile StgWord16 *x, StgWord val);
StgWord hs_atomic_and32(volatile StgWord32 *x, StgWord val);
StgWord64 hs_atomic_and64(volatile StgWord64 *x, StgWord64 val);
StgWord hs_atomic_nand8(volatile StgWord8 *x, StgWord val);
StgWord hs_atomic_nand16(volatile StgWord16 *x, StgWord val);
StgWord hs_atomic_nand32(volatile StgWord32 *x, StgWord val);
StgWord64 hs_atomic_nand64(volatile StgWord64 *x, StgWord64 val);
StgWord hs_atomic_or8(volatile StgWord8 *x, StgWord val);
StgWord hs_atomic_or16(volatile StgWord16 *x, StgWord val);
StgWord hs_atomic_or32(volatile StgWord32 *x, StgWord val);
StgWord64 hs_atomic_or64(volatile StgWord64 *x, StgWord64 val);
StgWord hs_atomic_xor8(volatile StgWord8 *x, StgWord val);
StgWord hs_atomic_xor16(volatile StgWord16 *x, StgWord val);
StgWord hs_atomic_xor32(volatile StgWord32 *x, StgWord val);
StgWord64 hs_atomic_xor64(volatile StgWord64 *x, StgWord64 val);
StgWord hs_cmpxchg8(volatile StgWord8 *x, StgWord old, StgWord new_);
StgWord hs_cmpxchg16(volatile StgWord16 *x, StgWord old, StgWord new_);
StgWord hs_cmpxchg32(volatile StgWord32 *x, StgWord old, StgWord new_);
StgWord hs_cmpxchg64(volatile StgWord64 *x, StgWord64 old, StgWord64 new_);
StgWord hs_atomicread8(volatile StgWord8 *x);
StgWord hs_atomicread16(volatile StgWord16 *x);
StgWord hs_atomicread32(volatile StgWord32 *x);
StgWord64 hs_atomicread64(volatile StgWord64 *x);
void hs_atomicwrite8(volatile StgWord8 *x, StgWord val);
void hs_atomicwrite16(volatile StgWord16 *x, StgWord val);
void hs_atomicwrite32(volatile StgWord32 *x, StgWord val);
void hs_atomicwrite64(volatile StgWord64 *x, StgWord64 val);

/* libraries/ghc-prim/cbits/bswap.c */
StgWord16 hs_bswap16(StgWord16 x);
StgWord32 hs_bswap32(StgWord32 x);
StgWord64 hs_bswap64(StgWord64 x);

/* TODO: longlong.c */

/* libraries/ghc-prim/cbits/popcnt.c */
StgWord hs_popcnt8(StgWord x);
StgWord hs_popcnt16(StgWord x);
StgWord hs_popcnt32(StgWord x);
StgWord hs_popcnt64(StgWord64 x);
StgWord hs_popcnt(StgWord x);

/* libraries/ghc-prim/cbits/word2float.c */
StgFloat hs_word2float32(StgWord x);
StgDouble hs_word2float64(StgWord x);

/* libraries/ghc-prim/cbits/clz.c */
StgWord hs_clz8(StgWord x);
StgWord hs_clz16(StgWord x);
StgWord hs_clz32(StgWord x);
StgWord hs_clz64(StgWord64 x);

/* libraries/ghc-prim/cbits/ctz.c */
StgWord hs_ctz8(StgWord x);
StgWord hs_ctz16(StgWord x);
StgWord hs_ctz32(StgWord x);
StgWord hs_ctz64(StgWord64 x);

#endif /* PRIM_H */
