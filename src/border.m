extern int g_connection;
extern struct window_manager g_window_manager;

static void border_update_window_notifications(uint32_t wid)
{
    int window_count = 0;
    uint32_t window_list[1024] = {};

    if (wid) window_list[window_count++] = wid;

    for (int window_index = 0; window_index < g_window_manager.window.capacity; ++window_index) {
        struct bucket *bucket = g_window_manager.window.buckets[window_index];
        while (bucket) {
            if (bucket->value) {
                struct window *window = bucket->value;
                if (window->border.id) {
                    window_list[window_count++] = window->id;
                }
            }

            bucket = bucket->next;
        }
    }

    SLSRequestNotificationsForWindows(g_connection, window_list, window_count);
}

bool border_should_order_in(struct window *window)
{
    return !window->application->is_hidden && !window_check_flag(window, WINDOW_MINIMIZE) && !window_check_flag(window, WINDOW_FULLSCREEN);
}

void border_show_all(void)
{
    for (int window_index = 0; window_index < g_window_manager.window.capacity; ++window_index) {
        struct bucket *bucket = g_window_manager.window.buckets[window_index];
        while (bucket) {
            if (bucket->value) {
                struct window *window = bucket->value;
                if (window->border.id && border_should_order_in(window)) {
                    SLSOrderWindow(g_connection, window->border.id, -1, window->id);
                }
            }

            bucket = bucket->next;
        }
    }
}

void border_hide_all(void)
{
    for (int window_index = 0; window_index < g_window_manager.window.capacity; ++window_index) {
        struct bucket *bucket = g_window_manager.window.buckets[window_index];
        while (bucket) {
            if (bucket->value) {
                struct window *window = bucket->value;
                if (window->border.id) {
                    SLSOrderWindow(g_connection, window->border.id, 0, 0);
                }
            }

            bucket = bucket->next;
        }
    }
}

void border_redraw(struct window *window)
{
    uint8_t is_ordered_in = false;
    SLSWindowIsOrderedIn(g_connection, window->border.id, &is_ordered_in);

    if (is_ordered_in) {
        SLSDisableUpdate(g_connection);
        SLSOrderWindow(g_connection, window->border.id, 0, 0);
    }

    CGContextClearRect(window->border.context, window->border.frame);
    CGContextAddPath(window->border.context, window->border.path_ref);

    if (g_window_manager.border_blur) {
        CGContextDrawPath(window->border.context, kCGPathFillStroke);
    } else {
        CGContextStrokePath(window->border.context);
    }

    CGContextFlush(window->border.context);

    if (is_ordered_in) {
        SLSOrderWindow(g_connection, window->border.id, -1, window->id);
        SLSReenableUpdate(g_connection);
    }
}

void border_resize(struct window *window, CGRect frame)
{
    if (window->border.region)   CFRelease(window->border.region);
    if (window->border.path_ref) CGPathRelease(window->border.path_ref);

    frame = CGRectInset(frame, -g_window_manager.border_width, -g_window_manager.border_width);
    CGSNewRegionWithRect(&frame, &window->border.region);
    window->border.frame.size = frame.size;

    window->border.path = (CGRect) {{ g_window_manager.border_width, g_window_manager.border_width }, { frame.size.width - 2.f*g_window_manager.border_width, frame.size.height - 2.f*g_window_manager.border_width }};
    window->border.path_ref = CGPathCreateWithRoundedRect(window->border.path, cgrect_clamp_x_radius(window->border.path, g_window_manager.border_radius), cgrect_clamp_y_radius(window->border.path, g_window_manager.border_radius), NULL);

    uint8_t is_ordered_in = false;
    SLSWindowIsOrderedIn(g_connection, window->border.id, &is_ordered_in);

    if (is_ordered_in) {
        SLSDisableUpdate(g_connection);
        SLSOrderWindow(g_connection, window->border.id, 0, 0);
    }

    SLSSetWindowShape(g_connection, window->border.id, 0.0f, 0.0f, window->border.region);
    CGContextClearRect(window->border.context, window->border.frame);
    CGContextAddPath(window->border.context, window->border.path_ref);

    if (g_window_manager.border_blur) {
        CGContextDrawPath(window->border.context, kCGPathFillStroke);
    } else {
        CGContextStrokePath(window->border.context);
    }

    CGContextFlush(window->border.context);

    if (is_ordered_in) {
        SLSOrderWindow(g_connection, window->border.id, -1, window->id);
        SLSReenableUpdate(g_connection);
    }
}

void border_move(struct window *window, CGRect frame)
{
    frame = CGRectInset(frame, -g_window_manager.border_width, -g_window_manager.border_width);
    SLSMoveWindow(g_connection, window->border.id, &frame.origin);
}

void border_activate(struct window *window)
{
    if (!window->border.id) return;

    CGContextSetRGBStrokeColor(window->border.context,
                               g_window_manager.active_border_color.r,
                               g_window_manager.active_border_color.g,
                               g_window_manager.active_border_color.b,
                               g_window_manager.active_border_color.a);
    border_redraw(window);
}

void border_deactivate(struct window *window)
{
    if (!window->border.id) return;

    CGContextSetRGBStrokeColor(window->border.context,
                               g_window_manager.normal_border_color.r,
                               g_window_manager.normal_border_color.g,
                               g_window_manager.normal_border_color.b,
                               g_window_manager.normal_border_color.a);
    border_redraw(window);
}

void border_ensure_same_space(struct window *window)
{
    int space_count;
    uint64_t *space_list = window_space_list(window, &space_count);
    if (!space_list) return;

    if (space_count > 1) {
        uint64_t tag = 1ULL << 11;
        SLSSetWindowTags(g_connection, window->border.id, &tag, 64);
    } else {
        uint64_t tag = 1ULL << 11;
        SLSClearWindowTags(g_connection, window->border.id, &tag, 64);
        SLSMoveWindowsToManagedSpace(g_connection, window->border.id_ref, space_list[0]);
    }
}

void border_hide(struct window *window)
{
    if (!window->border.id) return;

    SLSOrderWindow(g_connection, window->border.id, 0, 0);
}

void border_show(struct window *window)
{
    if (!window->border.id) return;

    SLSOrderWindow(g_connection, window->border.id, -1, window->id);
}

void border_create(struct window *window)
{
    if (window->border.id) return;

    if ((!window_rule_check_flag(window, WINDOW_RULE_MANAGED)) &&
        (!window_is_standard(window)) &&
        (!window_is_dialog(window))) {
        return;
    }

    CGRect frame = CGRectNull;
    CGSNewRegionWithRect(&frame, &window->border.region);

    uint64_t tag = 1ULL << 1;
    SLSNewWindow(g_connection, 2, 0, 0, window->border.region, &window->border.id);
    SLSSetWindowTags(g_connection, window->border.id, &tag, 64);
    sls_window_disable_shadow(window->border.id);
    SLSSetWindowResolution(g_connection, window->border.id, g_window_manager.border_resolution);
    SLSSetWindowOpacity(g_connection, window->border.id, 0);
    SLSSetWindowLevel(g_connection, window->border.id, window_level(window));

    if (g_window_manager.border_blur) {
        SLSSetWindowBackgroundBlurRadiusStyle(g_connection, window->border.id, 24, 1);
    }

    window->border.id_ref = cfarray_of_cfnumbers(&window->border.id, sizeof(uint32_t), 1, kCFNumberSInt32Type);
    window->border.context = SLWindowContextCreate(g_connection, window->border.id, 0);
    CGContextSetLineWidth(window->border.context, 2.f*g_window_manager.border_width);
    CGContextSetRGBStrokeColor(window->border.context,
                               g_window_manager.normal_border_color.r,
                               g_window_manager.normal_border_color.g,
                               g_window_manager.normal_border_color.b,
                               g_window_manager.normal_border_color.a);
    CGContextSetRGBFillColor(window->border.context, 0.96f, 0.96f, 0.96f, 0.075f);
    border_resize(window, window->frame);

    if (border_should_order_in(window)) {
        border_ensure_same_space(window);
        SLSOrderWindow(g_connection, window->border.id, -1, window->id);
    }

    border_update_window_notifications(window->id);
}

void border_destroy(struct window *window)
{
    if (!window->border.id) return;

    if (window->border.id_ref)   CFRelease(window->border.id_ref);
    if (window->border.region)   CFRelease(window->border.region);
    if (window->border.path_ref) CGPathRelease(window->border.path_ref);

    CGContextRelease(window->border.context);
    SLSReleaseWindow(g_connection, window->border.id);
    memset(&window->border, 0, sizeof(struct border));

    border_update_window_notifications(0);
}
