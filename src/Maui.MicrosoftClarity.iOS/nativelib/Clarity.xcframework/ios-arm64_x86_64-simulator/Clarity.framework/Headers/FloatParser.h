#ifndef FloatParser_h
#define FloatParser_h

#include <stdio.h>

typedef struct {
    float *values;
    size_t size;  // Current size of the array
    size_t capacity;  // Current capacity of the array
} clarity_ParseFloatsResult;

clarity_ParseFloatsResult *clarity_parseFloats(const char *value);
void clarity_FreeParseFloatsResult(clarity_ParseFloatsResult *array);

#endif /* FloatParser_h */
