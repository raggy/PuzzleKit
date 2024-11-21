class_name PieceAnimation3D
extends Node

signal started()
signal finished()
signal stopped()

var visual: PieceVisual3D
var piece_was_active: bool
var piece_will_be_active: bool
var piece_transform_start: Transform3D
var piece_transform_end: Transform3D

var _queued_after: PieceAnimation3D

func setup(_visual: PieceVisual3D):
	visual = _visual
	piece_was_active = visual.piece._previous_active
	piece_will_be_active = visual.piece.active
	piece_transform_start = visual.piece._previous_transform
	piece_transform_end = visual.piece.global_transform

func start() -> void:
	started.emit()

func finish() -> void:
	finished.emit()

func stop() -> void:
	stopped.emit()
