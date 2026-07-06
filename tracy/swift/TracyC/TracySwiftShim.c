#include "TracySwiftShim.h"

#ifdef TRACY_ENABLE
  #include "tracy/TracyC.h"
  #include <string.h>

  void TracySwiftFrameMarkStart(const char* name) { ___tracy_emit_frame_mark_start(name); }
  void TracySwiftFrameMarkEnd(const char* name)   { ___tracy_emit_frame_mark_end(name); }
  void TracySwiftFrameMarkNamed(const char* name) { ___tracy_emit_frame_mark(name); }

  void TracySwiftSetThreadName(const char* name) { ___tracy_set_thread_name(name); }

  TracySwiftZoneCtx TracySwiftZoneBegin(const char* name)
  {
      const uint32_t line = 0;
      const uint32_t color = 0;

      const char* file = "file";
      const char* func = "func";
      const uint64_t srcloc = ___tracy_alloc_srcloc_name(
          line,
          file, strlen(file),
          func, strlen(func),
          name, name ? strlen(name) : 0,
          color
      );

      int32_t active = 1;
      TracyCZoneCtx ctx = ___tracy_emit_zone_begin_alloc(srcloc, active);

      TracySwiftZoneCtx out;
      out.id = ctx.id;
      out.active = ctx.active;
      return out;
  }

  void TracySwiftZoneEnd(TracySwiftZoneCtx ctx)
  {
      TracyCZoneCtx tctx; tctx.id = ctx.id; tctx.active = ctx.active;
      ___tracy_emit_zone_end(tctx);
  }

  void TracySwiftZoneText(TracySwiftZoneCtx ctx, const char* text)
  {
      if (!text) return;
      TracyCZoneCtx tctx; tctx.id = ctx.id; tctx.active = ctx.active;
      ___tracy_emit_zone_text(tctx, text, strlen(text));
  }

  void TracySwiftZoneName(TracySwiftZoneCtx ctx, const char* name)
  {
      if (!name) return;
      TracyCZoneCtx tctx; tctx.id = ctx.id; tctx.active = ctx.active;
      ___tracy_emit_zone_name(tctx, name, strlen(name));
  }

  void TracySwiftZoneColor(TracySwiftZoneCtx ctx, uint32_t color)
  {
      TracyCZoneCtx tctx; tctx.id = ctx.id; tctx.active = ctx.active;
      ___tracy_emit_zone_color(tctx, color);
  }

  void TracySwiftZoneValue(TracySwiftZoneCtx ctx, uint64_t value)
  {
      TracyCZoneCtx tctx; tctx.id = ctx.id; tctx.active = ctx.active;
      ___tracy_emit_zone_value(tctx, value);
  }

  void TracySwiftPlot(const char* name, double value) { ___tracy_emit_plot(name, value); }
  void TracySwiftPlotF(const char* name, float value) { ___tracy_emit_plot_float(name, value); }
  void TracySwiftPlotI(const char* name, int64_t value) { ___tracy_emit_plot_int(name, value); }
  void TracySwiftPlotConfig(const char* name, int32_t type, int32_t step, int32_t fill, uint32_t color)
  {
      ___tracy_emit_plot_config(name, type, step, fill, color);
  }

  static void TracySwiftEmitMessage(int32_t severity, uint32_t color, const char* text)
  {
      if (!text) return;
      ___tracy_emit_logStringL((int8_t)severity, (int32_t)color, TRACY_CALLSTACK, text);
  }

  void TracySwiftMessage(const char* text)
  {
      TracySwiftEmitMessage(TracyMessageSeverityInfo, 0, text);
  }

  void TracySwiftMessageColor(const char* text, uint32_t color)
  {
      TracySwiftEmitMessage(TracyMessageSeverityInfo, color, text);
  }

  void TracySwiftMessageWithSeverity(const char* text, int32_t severity)
  {
      TracySwiftEmitMessage(severity, 0, text);
  }

  void TracySwiftMessageColorWithSeverity(const char* text, int32_t severity, uint32_t color)
  {
      TracySwiftEmitMessage(severity, color, text);
  }

  void TracySwiftAppInfo(const char* text)
  {
      if (!text) return;
      ___tracy_emit_message_appinfo(text, strlen(text));
  }

#else

  void TracySwiftFrameMarkStart(const char* name) { (void)name; }
  void TracySwiftFrameMarkEnd(const char* name)   { (void)name; }
  void TracySwiftFrameMarkNamed(const char* name) { (void)name; }

  void TracySwiftSetThreadName(const char* name) { (void)name; }

  TracySwiftZoneCtx TracySwiftZoneBegin(const char* name)
  {
      (void)name;
      TracySwiftZoneCtx ctx = { 0, 0 };
      return ctx;
  }
  void TracySwiftZoneEnd(TracySwiftZoneCtx ctx) { (void)ctx; }
  void TracySwiftZoneText(TracySwiftZoneCtx ctx, const char* text) { (void)ctx; (void)text; }
  void TracySwiftZoneName(TracySwiftZoneCtx ctx, const char* name) { (void)ctx; (void)name; }
  void TracySwiftZoneColor(TracySwiftZoneCtx ctx, uint32_t color) { (void)ctx; (void)color; }
  void TracySwiftZoneValue(TracySwiftZoneCtx ctx, uint64_t value) { (void)ctx; (void)value; }

  void TracySwiftPlot(const char* name, double value) { (void)name; (void)value; }
  void TracySwiftPlotF(const char* name, float value) { (void)name; (void)value; }
  void TracySwiftPlotI(const char* name, int64_t value) { (void)name; (void)value; }
  void TracySwiftPlotConfig(const char* name, int32_t type, int32_t step, int32_t fill, uint32_t color)
  { (void)name; (void)type; (void)step; (void)fill; (void)color; }

  void TracySwiftMessage(const char* text) { (void)text; }
  void TracySwiftMessageColor(const char* text, uint32_t color) { (void)text; (void)color; }
  void TracySwiftMessageWithSeverity(const char* text, int32_t severity) { (void)text; (void)severity; }
  void TracySwiftMessageColorWithSeverity(const char* text, int32_t severity, uint32_t color)
  { (void)text; (void)severity; (void)color; }

  void TracySwiftAppInfo(const char* text) { (void)text; }
#endif
