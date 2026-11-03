@tool
extends EditorPlugin

const SYNC_INTERVAL := 10.0

var sync_timer: Timer
var sync_running := false


func _enter_tree() -> void:
    sync_timer = Timer.new()
    sync_timer.wait_time = SYNC_INTERVAL
    sync_timer.timeout.connect(_sync_locks)
    add_child(sync_timer)

    # Synchronize immediately when the project opens.
    _sync_locks()
    sync_timer.start()


func _exit_tree() -> void:
    if sync_timer:
        sync_timer.stop()
        sync_timer.queue_free()


func _sync_locks() -> void:
    if sync_running:
        return

    sync_running = true

    var python := "python" if OS.get_name() == "Windows" else "python3"
    var script_path := ProjectSettings.globalize_path(
        "res://tools/godot_lock.py"
    )

    var output := []
    var exit_code := OS.execute(
        python,
        [script_path, "sync"],
        output,
        true
    )

    if exit_code != 0:
        push_warning(
            "Automatic lock sync failed: " + str(output)
        )

    sync_running = false
