#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void TracySwiftFrameMarkStart(const char* name);
void TracySwiftFrameMarkEnd(const char* name);
void TracySwiftFrameMarkNamed(const char* name);

void TracySwiftSetThreadName(const char* name);

typedef struct TracySwiftZoneCtx { uint32_t id; int32_t active; } TracySwiftZoneCtx;

TracySwiftZoneCtx TracySwiftZoneBegin(const char* name);
void TracySwiftZoneEnd(TracySwiftZoneCtx ctx);

void TracySwiftZoneText(TracySwiftZoneCtx ctx, const char* text);
void TracySwiftZoneName(TracySwiftZoneCtx ctx, const char* name);
void TracySwiftZoneColor(TracySwiftZoneCtx ctx, uint32_t color);
void TracySwiftZoneValue(TracySwiftZoneCtx ctx, uint64_t value);

void TracySwiftPlot(const char* name, double value);
void TracySwiftPlotF(const char* name, float value);
void TracySwiftPlotI(const char* name, int64_t value);
void TracySwiftPlotConfig(const char* name, int32_t type, int32_t step, int32_t fill, uint32_t color);

void TracySwiftMessage(const char* text);
void TracySwiftMessageColor(const char* text, uint32_t color);
void TracySwiftMessageWithSeverity(const char* text, int32_t severity);
void TracySwiftMessageColorWithSeverity(const char* text, int32_t severity, uint32_t color);

void TracySwiftAppInfo(const char* text);

#ifdef __cplusplus
}
#endif
