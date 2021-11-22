#ifndef NOTIFY_H
#define NOTIFY_H

void notify_init(void);
void notify(const char *subtitle, const char *format, ...);

#endif /* NOTIFY_H */