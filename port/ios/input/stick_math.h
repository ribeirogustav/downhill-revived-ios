/* Finite analog-stick mapping shared by UIKit inputs. GPL-3.0-or-later. */
#ifndef DHD_IOS_STICK_MATH_H
#define DHD_IOS_STICK_MATH_H
#include <math.h>
#include "stick.h"
static inline float touch_clamp(float value, float low, float high, float fallback) {
    return isfinite(value) ? fmaxf(low, fminf(high, value)) : fallback;
}
static inline void touch_normalize_stick(float x, float y, float deadzone, float sensitivity,
                                         float *out_x, float *out_y) {
    *out_x = *out_y = 0;
    if (!isfinite(x) || !isfinite(y)) return;
    /* Clamp before hypot to keep pathological finite inputs away from overflow. */
    x = touch_clamp(x, -1000, 1000, 0);
    y = touch_clamp(y, -1000, 1000, 0);
    /* Thumb drift near a cardinal direction must not trigger the other axis.
       Match the iOS pad's angular thresholds and ease into deliberate diagonals. */
    float *minor = fabsf(x) < fabsf(y) ? &x : &y;
    float dominant = fmaxf(fabsf(x), fabsf(y));
    if (dominant > 0) {
        float ratio = fabsf(*minor) / dominant;
        float blend = touch_clamp((ratio - .35f) / (.70f - .35f), 0, 1, 0);
        *minor *= blend * blend * (3 - 2 * blend);
    }
    float length = hypotf(x, y);
    float dz = touch_clamp(deadzone, 0, .95f, .05f);
    if (!(length > dz)) return; /* includes the neutral stick with zero deadzone */
    float gain = touch_clamp(sensitivity, 0, 3, 1);
    float magnitude = fminf(1, (length - dz) / (1 - dz) * gain);
    *out_x = x / length * magnitude;
    *out_y = y / length * magnitude;
}
/* Use the shared controller mapping after the touch deadzone has been removed.
   Raw centre + 127*x includes retail's full-lock band (finding 134). */
static inline uint8_t touch_stick_byte(float value) {
    value = touch_clamp(value, -1, 1, 0);
    int axis = (int)lroundf(value * (value < 0 ? 32768.0f : 32767.0f));
    return stick_byte(axis, 0);
}
#endif
