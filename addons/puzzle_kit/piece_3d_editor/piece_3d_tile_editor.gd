@tool
class_name Piece3DTileEditor
extends Node3D

@export var rigid_body: RigidBody3D
@export var mesh_instance: MeshInstance3D

var filled: bool: set = set_filled
var hovered: bool: set = set_hovered

func set_filled(value: bool):
    filled = value

func set_hovered(value: bool):
    hovered = value
    mesh_instance.visible = value
