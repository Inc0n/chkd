#ifndef SKHD_SYNTHESIZE_H
#define SKHD_SYNTHESIZE_H

/* void synthesize_key(char *key_string); */
/* void synthesize_text(char *text); */
void post_keyevent(uint32_t key, bool pressed);

void synthesize_key_prep();
/* void synthesize_key(); */
void synthesize_text(char *text);
/* extern void CGPostKeyboardEvent(CGCharCode code, CG key, bool pressed); */

#endif
