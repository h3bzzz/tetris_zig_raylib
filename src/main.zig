const std = @import("std");
const rl = @import("raylib");

const default_screen_w = 1280;
const default_screen_h = 720;

const grid_hor_size = 12;
const grid_vert_size = 20;
const lateral_speed = 10;
const turning_speed = 12;
const fast_fall_await_counter = 30;
const fading_time = 33;
const lock_delay_frames = 30;

const piece_colors = [7]rl.Color{
    rl.Color{ .r = 253, .g = 213, .b = 0, .a = 255 },  // yellow
    rl.Color{ .r = 255, .g = 128, .b =0, .a = 255 },   // orange
    rl.Color{ .r = 33, .g = 65, .b = 198, .a = 255 },  // blue
    rl.Color{ .r = 0, .g = 217, .b = 255, .a = 255 },  // cyan
    rl.Color{ .r = 175, .g = 41, .b = 138, .a = 255 }, // purple
    rl.Color{ .r = 114, .g = 203, .b = 59, .a = 255 }, // green
    rl.Color{ .r = 255, .g = 50, .b = 19, .a = 255 },  // red
};

const piece_shadow_colors = [7]rl.Color{
    rl.Color{ .r = 126, .g = 106, .b = 0, .a = 255 }, // 0: O shadow
    rl.Color{ .r = 127, .g = 64, .b = 0, .a = 255 },    // 1: L shadow
    rl.Color{ .r = 16, .g = 32, .b = 99, .a = 255 },  // 2: J shadow
    rl.Color{ .r = 0, .g = 108, .b = 127, .a = 255 }, // 3: I shadow
    rl.Color{ .r = 87, .g = 20, .b = 69, .a = 255 },  // 4: T shadow
    rl.Color{ .r = 57, .g = 101, .b = 29, .a = 255 }, // 5: S shadow
    rl.Color{ .r = 127, .g = 25, .b = 9, .a = 255 },  // 6: Z shadow
};

const ghost_alpha: u8 = 80;

const line_scores = [4]i32{ 100, 300, 500, 800 };

const GridSquare = enum(u8) {
    empty,
    moving,
    full,
    block,
    fading,
};

var game_started = false;
var game_over = false;
var pause = false;

var grid: [grid_hor_size][grid_vert_size]GridSquare = undefined;
var color_grid: [grid_hor_size][grid_vert_size]rl.Color = undefined;
var shadow_grid: [grid_hor_size][grid_vert_size]rl.Color = undefined;

var piece: [4][4]GridSquare = undefined;
var incoming_piece: [4][4]GridSquare = undefined;

var piece_position_x: i32 = 0;
var piece_position_y: i32 = 0;

var current_piece_type: i32 = 0;
var incoming_piece_type: i32 = 0;

var fading_color: rl.Color = rl.Color.gray;

var begin_play = true;
var piece_active = false;
var detection = false;
var line_to_delete = false;
var piece_landed = false;

var level: i32 = 1;
var lines: i32 = 0;
var score: i32 = 0;

var gravity_movement_counter: i32 = 0;
var lateral_movement_counter: i32 = 0;
var turn_movement_counter: i32 = 0;
var fast_fall_movement_counter: i32 = 0;
var fade_line_counter: i32 = 0;
var lock_delay_counter: i32 = 0;

var gravity_speed: i32 = 30;
var should_quit = false;

const Layout = struct {
    sw: i32,
    sh: i32,
    square_size: i32,
    grid_origin_x: f32,
    grid_origin_y: f32,
    panel_x: f32,
    panel_width: i32,
    font_title: i32,
    font_subtitle: i32,
    font_body: i32,
    font_small: i32,
    line_spacing: i32,
};

fn computeLayout() Layout {
    const sw = rl.getScreenWidth();
    const sh = rl.getScreenHeight();

    const grid_margin_y: i32 = 40;
    const panel_gap: i32 = 30;
    const panel_width: i32 = 200;

    const max_sq_by_height = @divTrunc(sh - grid_margin_y * 2, grid_vert_size);

    const needed_w = grid_hor_size * max_sq_by_height + panel_gap + panel_width;

    var square_size = max_sq_by_height;
    if (needed_w > sw) {
        square_size = @divTrunc(sw - panel_gap - panel_width, grid_hor_size);
    }

    square_size = @max(10, square_size);

    const grid_w = square_size * grid_hor_size;
    const content_w = grid_w + panel_gap + panel_width;

    const content_start_x = @divTrunc(sw - content_w, 2);

    const grid_origin_x = @as(f32, @floatFromInt(content_start_x));
    const grid_origin_y = @as(f32, @floatFromInt(grid_margin_y));
    const panel_x = @as(f32, @floatFromInt(content_start_x + grid_w + panel_gap));

    const base_font = @max(10, @divTrunc(square_size, 2));

    return Layout{
        .sw = sw,
        .sh = sh,
        .square_size = square_size,
        .grid_origin_x = grid_origin_x,
        .grid_origin_y = grid_origin_y,
        .panel_x = panel_x,
        .panel_width = panel_width,
        .font_title = base_font * 3,
        .font_subtitle = base_font,
        .font_body = base_font,
        .font_small = @max(8, base_font - 2),
        .line_spacing = base_font + 4,
    };
}

pub fn main() anyerror!void {
    rl.initWindow(default_screen_w, default_screen_h, "Tetris with Raylib and Zig");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    initGame();

    while (!rl.windowShouldClose() and !should_quit) {
        updateGame();
        drawGame();
    }

    unloadGame();
}

fn pieceColor(piece_type: i32) rl.Color {
    const idx: usize = @intCast(@min(@max(piece_type, 0), 6));
    return piece_colors[idx];
}

fn pieceShadowColor(piece_type: i32) rl.Color {
    const idx: usize = @intCast(@min(@max(piece_type, 0), 6));
    return piece_shadow_colors[idx];
}

fn ghostColor(piece_type: i32) rl.Color {
    const base = pieceColor(piece_type);
    return rl.Color{ .r = base.r, .g = base.g, .b = base.b, .a = ghost_alpha };
}

fn drawFilledCell(pos: rl.Vector2, size: i32, fill: rl.Color, shadow: rl.Color) void {
    rl.drawRectangleV(pos, .{ .x = @as(f32, @floatFromInt(size)), .y = @as(f32, @floatFromInt(size)) }, fill);

    rl.drawRectangleLines(
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        size,
        size,
        shadow,
    );
}

fn drawGhostCell(pos: rl.Vector2, size: i32, fill: rl.Color, shadow: rl.Color) void {
    rl.drawRectangleV(pos, .{ .x = @as(f32, @floatFromInt(size)), .y = @as(f32, @floatFromInt(size)) }, fill);
    rl.drawRectangleLines(
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        size,
        size,
        shadow,
    );
}

fn drawCellOutline(pos: rl.Vector2, size: i32) void {
    const s: f32 = @floatFromInt(size);
    const grid_line_color = rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 };

    rl.drawLineV(pos, .{ .x = pos.x + s, .y = pos.y }, grid_line_color);
    rl.drawLineV(pos, .{ .x = pos.x, .y = pos.y + s }, grid_line_color);
    rl.drawLineV(.{ .x = pos.x + s, .y = pos.y }, .{ .x = pos.x + s, .y = pos.y + s }, grid_line_color);
    rl.drawLineV(.{ .x = pos.x, .y = pos.y + s }, .{ .x = pos.x + s, .y = pos.y + s }, grid_line_color);
}

fn drawKeyLabel(label: [:0]const u8, action: [:0]const u8, x: i32, y: i32, font_size: i32) void {
    const key_width = rl.measureText(label, font_size);
    rl.drawText(label, x, y, font_size, rl.Color{ .r = 220, .g = 220, .b = 220, .a = 255 });
    rl.drawText(action, x + key_width + 8, y, font_size, rl.Color{ .r = 150, .g = 150, .b = 150, .a = 255 });
}

fn drawCenteredText(text: [:0]const u8, y: i32, font_size: i32, color: rl.Color, sw: i32) void {
    const text_w = rl.measureText(text, font_size);
    rl.drawText(text, @divTrunc(sw, 2) - @divTrunc(text_w, 2), y, font_size, color);
}

fn unloadGame() void {}

fn initGame() void {
    level = 1;
    lines = 0;
    score = 0;

    fading_color = rl.Color.gray;

    piece_position_x = 0;
    piece_position_y = 0;

    pause = false;

    begin_play = true;
    piece_active = false;
    detection = false;
    line_to_delete = false;
    piece_landed = false;

    gravity_movement_counter = 0;
    lateral_movement_counter = 0;
    turn_movement_counter = 0;
    fast_fall_movement_counter = 0;
    fade_line_counter = 0;
    lock_delay_counter = 0;

    gravity_speed = 30;

    game_over = false;

    current_piece_type = 0;
    incoming_piece_type = 0;

    for (0..grid_hor_size) |i| {
        for (0..grid_vert_size) |j| {
            if (j == grid_vert_size - 1 or
                i == 0 or
                i == grid_hor_size - 1)
            {
                grid[i][j] = .block;
            } else {
                grid[i][j] = .empty;
            }

            color_grid[i][j] = rl.Color{ .r = 50, .g = 50, .b = 50, .a = 255 };
            shadow_grid[i][j] = rl.Color{ .r = 30, .g = 30, .b = 30, .a = 255 };
        }
    }

    for (0..4) |i| {
        for (0..4) |j| {
            incoming_piece[i][j] = .empty;
            piece[i][j] = .empty;
        }
    }
}

fn updateGame() void {
    if (!game_started) {
        if (rl.isKeyPressed(.enter)) {
            game_started = true;
            initGame();
        }
        if (rl.isKeyPressed(.q)) {
            should_quit = true;
        }
        return;
    }

    if (game_over) {
        if (rl.isKeyPressed(.enter)) {
            initGame();
        }
        if (rl.isKeyPressed(.q)) {
            should_quit = true;
        }
        return;
    }

    if (rl.isKeyPressed(.p)) {
        pause = !pause;
    }

    if (rl.isKeyPressed(.q)) {
        should_quit = true;
        return;
    }

    if (pause) return;

    if (line_to_delete) {
        fade_line_counter += 1;

        if (@mod(fade_line_counter, 8) < 4) {
            fading_color = rl.Color{ .r = 255, .g = 80, .b = 80, .a = 255 };
        } else {
            fading_color = rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
        }

        if (fade_line_counter >= fading_time) {
            const deleted_lines = deleteCompleteLines();
            fade_line_counter = 0;
            line_to_delete = false;

            lines += deleted_lines;

            if (deleted_lines >= 1 and deleted_lines <= 4) {
                score += line_scores[@intCast(deleted_lines - 1)] * level;
            }

            level = @divTrunc(lines, 10) + 1;
            gravity_speed = @max(5, 30 - (level - 1) * 3);
        }
        return;
    }

    if (!piece_active) {
        piece_active = createPiece();
        fast_fall_movement_counter = 0;
        gravity_movement_counter = 0;
        lateral_movement_counter = 0;
        turn_movement_counter = 0;
        lock_delay_counter = 0;
        piece_landed = false;
    }

    fast_fall_movement_counter += 1;
    gravity_movement_counter += 1;
    lateral_movement_counter += 1;
    turn_movement_counter += 1;

    if (rl.isKeyPressed(.space)) {
        const drop_distance = calculateGhostOffset();
        if (drop_distance > 0) {
            var j: i32 = grid_vert_size - 2;
            while (j >= 0) : (j -= 1) {
                for (1..grid_hor_size - 1) |i| {
                    if (grid[i][@intCast(j)] == .moving) {
                        grid[i][@intCast(j)] = .empty;
                        grid[i][@intCast(j + drop_distance)] = .moving;
                    }
                }
            }
            piece_position_y += drop_distance;
            score += drop_distance * 2;
            detection = true;
            piece_landed = true;
            lock_delay_counter = 0;
        }
    }

    if (rl.isKeyPressed(.left) or rl.isKeyPressed(.right)) {
        lateral_movement_counter = lateral_speed;
        if (piece_landed) {
            lock_delay_counter = 0;
        }
    }
    if (rl.isKeyPressed(.up)) {
        turn_movement_counter = turning_speed;
        if (piece_landed) {
            lock_delay_counter = 0;
        }
    }

    if (rl.isKeyDown(.down) and
        fast_fall_movement_counter >= fast_fall_await_counter)
    {
        gravity_movement_counter += gravity_speed;
    }

    if (piece_landed and !detection) {
        piece_landed = false;
        lock_delay_counter = 0;
    }

    if (detection) {
        piece_landed = true;
        lock_delay_counter += 1;

        if (lock_delay_counter >= lock_delay_frames) {
            checkDetection(&detection);
            resolveFallingMovement(&detection, &piece_active);
            checkCompletion(&line_to_delete);
            piece_landed = false;
            lock_delay_counter = 0;
        }
    } else {
        if (gravity_movement_counter >= gravity_speed) {
            checkDetection(&detection);
            resolveFallingMovement(&detection, &piece_active);
            checkCompletion(&line_to_delete);
            gravity_movement_counter = 0;
        }
    }

    if (lateral_movement_counter >= lateral_speed) {
        if (!resolveLateralMovement()) {
            lateral_movement_counter = 0;
        }
    }

    if (turn_movement_counter >= turning_speed) {
        if (resolveTurnMovement()) {
            turn_movement_counter = 0;
        }
    }

    for (0..2) |j| {
        for (1..grid_hor_size - 1) |i| {
            if (grid[i][j] == .full) {
                game_over = true;
                return;
            }
        }
    }
}

fn calculateGhostOffset() i32 {
    var offset: i32 = 0;
    var can_fall = true;

    while (can_fall) {
        for (0..4) |x| {
            for (0..4) |y| {
                if (piece[x][y] == .moving) {
                    const gx: i32 = piece_position_x + @as(i32, @intCast(x));
                    const gy: i32 = piece_position_y + @as(i32, @intCast(y)) + offset + 1;

                    if (gy >= grid_vert_size - 1 or
                        gx <= 0 or
                        gx >= grid_hor_size - 1)
                    {
                        can_fall = false;
                        break;
                    }

                    const cell = grid[@intCast(gx)][@intCast(gy)];
                    if (cell == .full or cell == .block) {
                        can_fall = false;
                        break;
                    }
                }
            }
            if (!can_fall) break;
        }

        if (can_fall) {
            offset += 1;
        }
    }

    return offset;
}

fn drawGame() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    const layout = computeLayout();

    rl.clearBackground(rl.Color{ .r = 15, .g = 15, .b = 15, .a = 255 });

    if (!game_started) {
        drawStartScreen(layout);
        return;
    }

    if (!game_over) {
        drawMainGame(layout);
    } else {
        drawGameOverScreen(layout);
    }
}

fn drawStartScreen(layout: Layout) void {
    drawCenteredText("TETRIS", @divTrunc(layout.sh, 2) - layout.font_title * 2, layout.font_title, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, layout.sw);

    drawCenteredText("PRESS [ENTER] TO START", @divTrunc(layout.sh, 2) + @divTrunc(layout.font_title, 2), layout.font_subtitle, rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 }, layout.sw);

    const ctrl_x = @divTrunc(layout.sw, 2) - 120;
    var ctrl_y = @divTrunc(layout.sh, 2) + layout.font_title + layout.line_spacing * 2;

    drawKeyLabel("[LEFT/RIGHT]", "Move Left / Right", ctrl_x, ctrl_y, layout.font_body);
    ctrl_y += layout.line_spacing;
    drawKeyLabel("[UP]", "Rotate Piece", ctrl_x, ctrl_y, layout.font_body);
    ctrl_y += layout.line_spacing;
    drawKeyLabel("[DOWN]", "Soft Drop", ctrl_x, ctrl_y, layout.font_body);
    ctrl_y += layout.line_spacing;
    drawKeyLabel("[SPACE]", "Hard Drop", ctrl_x, ctrl_y, layout.font_body);
    ctrl_y += layout.line_spacing;
    drawKeyLabel("[P]", "Pause Game", ctrl_x, ctrl_y, layout.font_body);
    ctrl_y += layout.line_spacing;
    drawKeyLabel("[Q]", "Quit", ctrl_x, ctrl_y, layout.font_body);
}

fn drawMainGame(layout: Layout) void {
    const sq = layout.square_size;
    const start_x = layout.grid_origin_x;
    const grid_start_y = layout.grid_origin_y;

    rl.drawRectangleV(
        .{ .x = start_x, .y = grid_start_y },
        .{ .x = @as(f32, @floatFromInt(grid_hor_size * sq)), .y = @as(f32, @floatFromInt(grid_vert_size * sq)) },
        rl.Color{ .r = 20, .g = 20, .b = 20, .a = 255 },
    );

    rl.drawRectangleLines(
        @intFromFloat(start_x),
        @intFromFloat(grid_start_y),
        grid_hor_size * sq,
        grid_vert_size * sq,
        rl.Color{ .r = 60, .g = 60, .b = 60, .a = 255 },
    );

    if (piece_active and !line_to_delete) {
        const ghost_offset = calculateGhostOffset();
        if (ghost_offset > 0) {
            var ghost_pos = rl.Vector2{
                .x = start_x + @as(f32, @floatFromInt(piece_position_x * sq)),
                .y = grid_start_y + @as(f32, @floatFromInt((piece_position_y + ghost_offset) * sq)),
            };
            const ghost_fill = ghostColor(current_piece_type);
            const ghost_shadow = rl.Color{ .r = pieceShadowColor(current_piece_type).r, .g = pieceShadowColor(current_piece_type).g, .b = pieceShadowColor(current_piece_type).b, .a = ghost_alpha };

            for (0..4) |y| {
                for (0..4) |x| {
                    if (piece[x][y] == .moving) {
                        drawGhostCell(ghost_pos, sq, ghost_fill, ghost_shadow);
                    }
                    ghost_pos.x += @as(f32, @floatFromInt(sq));
                }
                ghost_pos.x = start_x + @as(f32, @floatFromInt(piece_position_x * sq));
                ghost_pos.y += @as(f32, @floatFromInt(sq));
            }
        }
    }

    var offset = rl.Vector2{ .x = start_x, .y = grid_start_y };
    for (0..grid_vert_size) |j| {
        for (0..grid_hor_size) |i| {
            switch (grid[i][j]) {
                .empty => {
                    drawCellOutline(offset, sq);
                },

                .full => {
                    drawFilledCell(offset, sq, color_grid[i][j], shadow_grid[i][j]);
                },

                .moving => {
                    drawFilledCell(
                        offset,
                        sq,
                        pieceColor(current_piece_type),
                        pieceShadowColor(current_piece_type),
                    );
                },

                .block => {
                    rl.drawRectangleV(
                        offset,
                        .{ .x = @as(f32, @floatFromInt(sq)), .y = @as(f32, @floatFromInt(sq)) },
                        rl.Color{ .r = 50, .g = 50, .b = 50, .a = 255 },
                    );
                    rl.drawRectangleLines(
                        @intFromFloat(offset.x),
                        @intFromFloat(offset.y),
                        sq,
                        sq,
                        rl.Color{ .r = 70, .g = 70, .b = 70, .a = 255 },
                    );
                },

                .fading => {
                    rl.drawRectangleV(
                        offset,
                        .{ .x = @as(f32, @floatFromInt(sq)), .y = @as(f32, @floatFromInt(sq)) },
                        fading_color,
                    );
                },
            }

            offset.x += @as(f32, @floatFromInt(sq));
        }

        offset.x = start_x;
        offset.y += @as(f32, @floatFromInt(sq));
    }

    drawPanel(layout);

    if (pause) {
        drawCenteredText("GAME PAUSED", @divTrunc(layout.sh, 2) - @divTrunc(layout.font_title, 2), layout.font_title, rl.Color{ .r = 220, .g = 220, .b = 220, .a = 255 }, layout.sw);
    }
}

fn drawPanel(layout: Layout) void {
    const sq = layout.square_size;
    const panel_x = layout.panel_x;
    var offset_y: f32 = layout.grid_origin_y;

    rl.drawText("NEXT:", @intFromFloat(panel_x), @intFromFloat(offset_y), layout.font_body, rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
    offset_y += @as(f32, @floatFromInt(layout.line_spacing));

    const preview_start_x = panel_x;
    var preview_offset = rl.Vector2{ .x = preview_start_x, .y = offset_y };

    for (0..4) |j| {
        for (0..4) |i| {
            switch (incoming_piece[i][j]) {
                .empty => {
                    drawCellOutline(preview_offset, sq);
                },
                .moving => {
                    drawFilledCell(
                        preview_offset,
                        sq,
                        pieceColor(incoming_piece_type),
                        pieceShadowColor(incoming_piece_type),
                    );
                },
                else => {},
            }

            preview_offset.x += @as(f32, @floatFromInt(sq));
        }

        preview_offset.x = preview_start_x;
        preview_offset.y += @as(f32, @floatFromInt(sq));
    }

    var hud_y: i32 = @as(i32, @intFromFloat(preview_offset.y)) + layout.line_spacing;
    const hud_x: i32 = @intFromFloat(panel_x);

    drawHudLine4("LINES", lines, hud_x, &hud_y, layout);
    drawHudLine2("LEVEL", level, hud_x, &hud_y, layout);
    drawHudLine8("SCORE", score, hud_x, &hud_y, layout);

    hud_y += layout.line_spacing;
    rl.drawText("CONTROLS", hud_x, hud_y, layout.font_body, rl.Color{ .r = 160, .g = 160, .b = 160, .a = 255 });
    hud_y += layout.line_spacing;

    drawKeyLabel("[LEFT/RIGHT]", "Move", hud_x, hud_y, layout.font_small);
    hud_y += layout.line_spacing;
    drawKeyLabel("[UP]", "Rotate", hud_x, hud_y, layout.font_small);
    hud_y += layout.line_spacing;
    drawKeyLabel("[DOWN]", "Soft Drop", hud_x, hud_y, layout.font_small);
    hud_y += layout.line_spacing;
    drawKeyLabel("[SPACE]", "Hard Drop", hud_x, hud_y, layout.font_small);
    hud_y += layout.line_spacing;
    drawKeyLabel("[P]", "Pause", hud_x, hud_y, layout.font_small);
    hud_y += layout.line_spacing;
    drawKeyLabel("[Q]", "Quit", hud_x, hud_y, layout.font_small);
}

fn drawHudLine4(label: []const u8, value: i32, x: i32, y_ptr: *i32, layout: Layout) void {
    var buf: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, "{s}  {d:0>4}", .{ label, value }) catch unreachable;
    rl.drawText(text, x, y_ptr.*, layout.font_body, rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
    y_ptr.* += layout.line_spacing;
}

fn drawHudLine2(label: []const u8, value: i32, x: i32, y_ptr: *i32, layout: Layout) void {
    var buf: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, "{s}  {d:0>2}", .{ label, value }) catch unreachable;
    rl.drawText(text, x, y_ptr.*, layout.font_body, rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
    y_ptr.* += layout.line_spacing;
}

fn drawHudLine8(label: []const u8, value: i32, x: i32, y_ptr: *i32, layout: Layout) void {
    var buf: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, "{s}  {d:0>8}", .{ label, value }) catch unreachable;
    rl.drawText(text, x, y_ptr.*, layout.font_body, rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
    y_ptr.* += layout.line_spacing;
}

fn drawGameOverScreen(layout: Layout) void {
    var buf: [64]u8 = undefined;
    const score_text = std.fmt.bufPrintZ(&buf, "SCORE: {d}", .{score}) catch unreachable;
    drawCenteredText(score_text, @divTrunc(layout.sh, 2) - layout.font_title * 2, layout.font_subtitle * 2, rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 }, layout.sw);

    drawCenteredText("GAME OVER", @divTrunc(layout.sh, 2) - @divTrunc(layout.font_title, 2), layout.font_title, rl.Color{ .r = 255, .g = 80, .b = 80, .a = 255 }, layout.sw);

    drawCenteredText("PRESS [ENTER] TO PLAY AGAIN", @divTrunc(layout.sh, 2) + layout.line_spacing * 2, layout.font_subtitle, rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 }, layout.sw);
}

fn createPiece() bool {
    piece_position_x = @divTrunc(grid_hor_size - 4, 2);
    piece_position_y = 0;

    if (begin_play) {
        getRandomPiece();
        begin_play = false;
    }

    for (0..4) |i| {
        for (0..4) |j| {
            piece[i][j] = incoming_piece[i][j];
        }
    }

    current_piece_type = incoming_piece_type;

    getRandomPiece();

    for (0..4) |i| {
        for (0..4) |j| {
            if (piece[i][j] == .moving) {
                const gx: usize = @intCast(piece_position_x + @as(i32, @intCast(i)));
                const gy: usize = j;
                grid[gx][gy] = .moving;
            }
        }
    }

    return true;
}

fn getRandomPiece() void {
    const random = rl.getRandomValue(0, 6);
    incoming_piece_type = random;

    for (0..4) |i| {
        for (0..4) |j| {
            incoming_piece[i][j] = .empty;
        }
    }

    switch (random) {
        0 => {
            incoming_piece[1][1] = .moving;
            incoming_piece[2][1] = .moving;
            incoming_piece[1][2] = .moving;
            incoming_piece[2][2] = .moving;
        },
        1 => {
            incoming_piece[1][0] = .moving;
            incoming_piece[1][1] = .moving;
            incoming_piece[1][2] = .moving;
            incoming_piece[2][2] = .moving;
        },
        2 => {
            incoming_piece[1][2] = .moving;
            incoming_piece[2][0] = .moving;
            incoming_piece[2][1] = .moving;
            incoming_piece[2][2] = .moving;
        },
        3 => {
            incoming_piece[0][1] = .moving;
            incoming_piece[1][1] = .moving;
            incoming_piece[2][1] = .moving;
            incoming_piece[3][1] = .moving;
        },
        4 => {
            incoming_piece[1][0] = .moving;
            incoming_piece[1][1] = .moving;
            incoming_piece[1][2] = .moving;
            incoming_piece[2][1] = .moving;
        },
        5 => {
            incoming_piece[1][1] = .moving;
            incoming_piece[2][1] = .moving;
            incoming_piece[2][2] = .moving;
            incoming_piece[3][2] = .moving;
        },
        6 => {
            incoming_piece[1][2] = .moving;
            incoming_piece[2][2] = .moving;
            incoming_piece[2][1] = .moving;
            incoming_piece[3][1] = .moving;
        },
        else => unreachable,
    }
}

fn resolveFallingMovement(
    detection_ptr: *bool,
    piece_active_ptr: *bool,
) void {
    if (detection_ptr.*) {
        var j: i32 = grid_vert_size - 2;

        while (j >= 0) : (j -= 1) {
            for (1..grid_hor_size - 1) |i| {
                if (grid[i][@intCast(j)] == .moving) {
                    grid[i][@intCast(j)] = .full;
                    color_grid[i][@intCast(j)] = pieceColor(current_piece_type);
                    shadow_grid[i][@intCast(j)] = pieceShadowColor(current_piece_type);
                    detection_ptr.* = false;
                    piece_active_ptr.* = false;
                }
            }
        }
    } else {
        var j: i32 = grid_vert_size - 2;

        while (j >= 0) : (j -= 1) {
            for (1..grid_hor_size - 1) |i| {
                if (grid[i][@intCast(j)] == .moving) {
                    grid[i][@intCast(j + 1)] = .moving;
                    grid[i][@intCast(j)] = .empty;
                }
            }
        }

        piece_position_y += 1;
    }
}

fn checkDetection(detection_ptr: *bool) void {
    detection_ptr.* = false;

    var j: i32 = grid_vert_size - 2;

    while (j >= 0) : (j -= 1) {
        for (1..grid_hor_size - 1) |i| {
            if (grid[i][@intCast(j)] == .moving and
                (grid[i][@intCast(j + 1)] == .full or
                    grid[i][@intCast(j + 1)] == .block))
            {
                detection_ptr.* = true;
            }
        }
    }
}

fn resolveLateralMovement() bool {
    var collision = false;

    if (rl.isKeyDown(.left)) {
        var j: i32 = grid_vert_size - 2;
        while (j >= 0) : (j -= 1) {
            for (1..grid_hor_size - 1) |i| {
                if (grid[i][@intCast(j)] == .moving) {
                    if (i - 1 == 0 or grid[i - 1][@intCast(j)] == .full) {
                        collision = true;
                    }
                }
            }
        }

        if (!collision) {
            var move_j: i32 = grid_vert_size - 2;
            while (move_j >= 0) : (move_j -= 1) {
                for (1..grid_hor_size - 1) |i| {
                    if (grid[i][@intCast(move_j)] == .moving) {
                        grid[i - 1][@intCast(move_j)] = .moving;
                        grid[i][@intCast(move_j)] = .empty;
                    }
                }
            }
            piece_position_x -= 1;
        }
    } else if (rl.isKeyDown(.right)) {
        var j: i32 = grid_vert_size - 2;
        while (j >= 0) : (j -= 1) {
            for (1..grid_hor_size - 1) |i| {
                if (grid[i][@intCast(j)] == .moving) {
                    if (i + 1 == grid_hor_size - 1 or
                        grid[i + 1][@intCast(j)] == .full)
                    {
                        collision = true;
                    }
                }
            }
        }

        if (!collision) {
            var move_j: i32 = grid_vert_size - 2;
            while (move_j >= 0) : (move_j -= 1) {
                var i: i32 = grid_hor_size - 1;
                while (i >= 1) : (i -= 1) {
                    if (grid[@intCast(i)][@intCast(move_j)] == .moving) {
                        grid[@intCast(i + 1)][@intCast(move_j)] = .moving;
                        grid[@intCast(i)][@intCast(move_j)] = .empty;
                    }
                }
            }
            piece_position_x += 1;
        }
    }

    return collision;
}

fn resolveTurnMovement() bool {
    if (!rl.isKeyDown(.up)) return false;

    var rotated: [4][4]GridSquare = undefined;
    for (0..4) |y| {
        for (0..4) |x| {
            rotated[x][3 - y] = piece[y][x];
        }
    }

    for (0..4) |x| {
        for (0..4) |y| {
            if (rotated[x][y] == .moving) {
                const gx = piece_position_x + @as(i32, @intCast(x));
                const gy = piece_position_y + @as(i32, @intCast(y));

                if (gx < 0 or
                    gx >= grid_hor_size or
                    gy < 0 or
                    gy >= grid_vert_size)
                {
                    return false;
                }

                const cell = grid[@intCast(gx)][@intCast(gy)];
                if (cell != .empty and cell != .moving) {
                    return false;
                }
            }
        }
    }

    for (0..grid_hor_size) |x| {
        for (0..grid_vert_size) |y| {
            if (grid[x][y] == .moving) {
                grid[x][y] = .empty;
            }
        }
    }

    piece = rotated;

    for (0..4) |x| {
        for (0..4) |y| {
            if (piece[x][y] == .moving) {
                const gx: usize = @intCast(piece_position_x + @as(i32, @intCast(x)));
                const gy: usize = @intCast(piece_position_y + @as(i32, @intCast(y)));
                grid[gx][gy] = .moving;
            }
        }
    }

    return true;
}

fn checkCompletion(line_to_delete_ptr: *bool) void {
    var j: i32 = grid_vert_size - 2;

    while (j >= 0) : (j -= 1) {
        var count: i32 = 0;

        for (1..grid_hor_size - 1) |i| {
            if (grid[i][@intCast(j)] == .full) {
                count += 1;
            }
        }

        if (count == grid_hor_size - 2) {
            line_to_delete_ptr.* = true;

            for (1..grid_hor_size - 1) |x| {
                grid[x][@intCast(j)] = .fading;
            }
        }
    }
}

fn deleteCompleteLines() i32 {
    var deleted_lines: i32 = 0;

    var j: i32 = grid_vert_size - 2;

    while (j >= 0) : (j -= 1) {
        while (grid[1][@intCast(j)] == .fading) {
            for (1..grid_hor_size - 1) |i| {
                grid[i][@intCast(j)] = .empty;
            }

            var jj: i32 = j - 1;
            while (jj >= 0) : (jj -= 1) {
                for (1..grid_hor_size - 1) |ii| {
                    switch (grid[ii][@intCast(jj)]) {
                        .full => {
                            grid[ii][@intCast(jj + 1)] = .full;
                            color_grid[ii][@intCast(jj + 1)] = color_grid[ii][@intCast(jj)];
                            shadow_grid[ii][@intCast(jj + 1)] = shadow_grid[ii][@intCast(jj)];
                            grid[ii][@intCast(jj)] = .empty;
                        },
                        .fading => {
                            grid[ii][@intCast(jj + 1)] = .fading;
                            color_grid[ii][@intCast(jj + 1)] = color_grid[ii][@intCast(jj)];
                            shadow_grid[ii][@intCast(jj + 1)] = shadow_grid[ii][@intCast(jj)];
                            grid[ii][@intCast(jj)] = .empty;
                        },
                        else => {},
                    }
                }
            }

            deleted_lines += 1;
        }
    }

    return deleted_lines;
}
