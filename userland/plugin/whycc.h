/* whycc: a .metallib's kernel functions compiled for the Adreno 509, behind a C interface (whycc.cpp) */
#ifndef WHYCC_H
#define WHYCC_H

#include <stddef.h>
#include "why5.h"

#ifdef __cplusplus
extern "C" {
#endif

struct whycc_lib;

struct whycc_fc {
	uint32_t index;
	uint64_t bits;
};

#define WHYCC_MAX_UBER_BUFS 8
#define WHYCC_UBER_BUF_CAP  1024

struct whycc_uber_buf {
	uint32_t binding;
	uint32_t len;
	uint8_t mask[WHYCC_UBER_BUF_CAP];
};

struct whycc_uber_val {
	uint32_t binding;
	uint32_t len;
	const uint8_t * bytes;
	const uint8_t * fold;
};

/* the library from its bytes (copied); NULL with the reason in WHY */
struct whycc_lib * whycc_open(const void * data, size_t size, char * why, size_t whysize);
void whycc_close(struct whycc_lib * l);
unsigned whycc_function_count(struct whycc_lib * l);
const char * whycc_function_name(struct whycc_lib * l, unsigned i, int * type);
int whycc_resolve_fc_name(struct whycc_lib * l, const char * fname, const char * cname, uint32_t * out_index);
/* 1 with OUT filled (free it with whycc_kernel_free), 0 with the reason in WHY */
int whycc_compile(struct whycc_lib * l, const char * name, const struct whycc_fc * fcs, uint32_t nfcs,
    struct why5_kernel * out, char * why, size_t whysize);
void whycc_kernel_free(struct why5_kernel * k);
/* a vertex and a fragment function compiled and linked (render pipeline); 1 with VS, FS and LINK filled (free each stage with
 * whycc_stage_free), 0 with the reason in WHY */
int whycc_compile_program(struct whycc_lib * lv, const char * vname, const struct whycc_fc * vfcs, uint32_t nvfcs,
    struct whycc_lib * lf, const char * fname, const struct whycc_fc * ffcs, uint32_t nffcs,
    struct why5_stage * vs, struct why5_stage * fs, struct why5_link * link, char * why, size_t whysize);
int whycc_compile_vs(struct whycc_lib * lv, const char * vname, const struct whycc_fc * vfcs, uint32_t nvfcs,
    struct why5_stage * vs, char * why, size_t whysize);
int whycc_uber_info(struct whycc_lib * lf, const char * fname, const struct whycc_fc * ffcs, uint32_t nffcs,
    struct whycc_uber_buf * out_bufs, uint32_t * out_nbufs, uint32_t * out_ifs, char * summary, size_t sumsize,
    char * why, size_t whysize);
int whycc_compile_program_spec(struct whycc_lib * lv, const char * vname, const struct whycc_fc * vfcs, uint32_t nvfcs,
    struct whycc_lib * lf, const char * fname, const struct whycc_fc * ffcs, uint32_t nffcs,
    const struct whycc_uber_val * uvals, uint32_t nuvals,
    struct why5_stage * vs, struct why5_stage * fs, struct why5_link * link, char * why, size_t whysize);
void whycc_stage_free(struct why5_stage * s);
/* function I of the library compiled alone: 1 with a SUMMARY of what it uses, 0 with the reason in WHY, -1 past the end */
int whycc_probe(struct whycc_lib * l, unsigned i, char * summary, size_t ssize, char * why, size_t whysize);

void whycc_survey_pairs(struct whycc_lib * l);

#ifdef __cplusplus
}
#endif

#endif
