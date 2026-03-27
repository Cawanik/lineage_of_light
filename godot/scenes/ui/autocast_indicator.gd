extends Control

var ability_id: String = "magic_bolt"
var _offset: float = 0.0
const SPEED: float = 12.0   # пикселей в секунду вдоль периметра
const DASH: float = 14.0    # длина штриха
const GAP: float = 8.0     # длина пробела
const CYCLE: float = DASH + GAP
const MARGIN: float = 1.5
const LINE_W: float = 1.5
const COLOR := Color(0.85, 0.55, 1.0, 0.95)


func _is_active() -> bool:
	if not PhaseManager.is_combat_phase():
		return false
	var sm = get_node_or_null("/root/SkillManager")
	if sm and not sm.is_ability_unlocked(ability_id):
		return false
	return true


func _process(delta: float) -> void:
	if not _is_active():
		queue_redraw()  # перерисовать чтобы скрыть
		return
	_offset = fmod(_offset + delta * SPEED, CYCLE)
	queue_redraw()


func _draw() -> void:
	if not _is_active():
		return
	var m = MARGIN
	var w = size.x - m
	var h = size.y - m

	# Периметр как единый массив точек
	var perimeter: Array[Vector2] = [
		Vector2(m, m),
		Vector2(w, m),
		Vector2(w, h),
		Vector2(m, h),
		Vector2(m, m),  # замыкаем
	]

	# Суммарные длины отрезков → позиции на периметре
	var seg_lengths: Array[float] = []
	var total: float = 0.0
	for i in range(perimeter.size() - 1):
		var l = perimeter[i].distance_to(perimeter[i + 1])
		seg_lengths.append(l)
		total += l

	# Рисуем штрихи вдоль всего периметра как единой линии
	var pos = -_offset
	while pos < total:
		var ds = maxf(pos, 0.0)
		var de = minf(pos + DASH, total)
		if ds < de:
			_draw_segment_on_perimeter(perimeter, seg_lengths, ds, de)
		pos += CYCLE


func _draw_segment_on_perimeter(pts: Array[Vector2], lens: Array[float], from_d: float, to_d: float) -> void:
	var accumulated: float = 0.0
	for i in range(lens.size()):
		var seg_start = accumulated
		var seg_end = accumulated + lens[i]

		if to_d <= seg_start:
			break
		if from_d >= seg_end:
			accumulated = seg_end
			continue

		var t0 = (maxf(from_d, seg_start) - seg_start) / lens[i]
		var t1 = (minf(to_d, seg_end) - seg_start) / lens[i]
		var a = pts[i].lerp(pts[i + 1], t0)
		var b = pts[i].lerp(pts[i + 1], t1)
		draw_line(a, b, COLOR, LINE_W)

		accumulated = seg_end
