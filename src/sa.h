#ifndef SA_H
#define SA_H

extern unsigned char __src_osax_payload[];
extern unsigned int __src_osax_payload_len;
extern unsigned char __src_osax_loader[];
extern unsigned int __src_osax_loader_len;

extern bool workspace_is_macos_monterey(void);
extern bool workspace_is_macos_bigsur(void);

int scripting_addition_load(void);
int scripting_addition_uninstall(void);

bool scripting_addition_create_space(uint64_t sid);
bool scripting_addition_destroy_space(uint64_t sid);
bool scripting_addition_focus_space(uint64_t sid);
bool scripting_addition_move_space_after_space(uint64_t src_sid, uint64_t dst_sid, bool focus);
bool scripting_addition_move_window(uint32_t wid, int x, int y);
bool scripting_addition_set_opacity(uint32_t wid, float opacity, float duration);
bool scripting_addition_set_layer(uint32_t wid, int layer);
bool scripting_addition_set_sticky(uint32_t wid, bool sticky);
bool scripting_addition_set_shadow(uint32_t wid, bool shadow);
bool scripting_addition_focus_window(uint32_t wid);
bool scripting_addition_scale_window(uint32_t wid, float x, float y, float w, float h);
bool scripting_addition_swap_window_proxy(uint32_t a_wid, uint32_t b_wid, float opacity, int order);
bool scripting_addition_order_window(uint32_t a_wid, int order, uint32_t b_wid);
bool scripting_addition_transform_window_list(float alpha, uint32_t* wid, float* x, float* y, float* s_w, float* s_h, uint32_t count);

#endif
