from pathlib import Path

rooms = {
    "R2": {
        "id": "R2",
        "prev": "R1",
        "next": "F1",
        "bg": "bg_r2.png",
        "platforms": [((240, 255), (480, 40))],
    },
    "F1": {
        "id": "F1",
        "prev": "",
        "next": "F2",
        "bg": "bg_f1.png",
        "platforms": [((80, 255), (160, 40)), ((240, 235), (100, 20)), ((400, 215), (140, 20))],
    },
    "F2": {
        "id": "F2",
        "prev": "F1",
        "next": "F3",
        "bg": "bg_f2.png",
        "platforms": [((240, 255), (480, 40))],
    },
    "F5": {
        "id": "F5",
        "prev": "",
        "next": "",
        "bg": "bg_f5.png",
        "platforms": [((240, 255), (480, 40))],
    }
}

for r_name, d in rooms.items():
    shape_counter = 1
    content = f'''[gd_scene load_steps=8 format=3 uid="uid://room_{r_name.lower()}_001"]

[ext_resource type="Script" path="res://scripts/rooms/base_room.gd" id="1_room"]
[ext_resource type="Texture2D" path="res://assets/processed/rooms/{d['bg']}" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/actors/kirana.tscn" id="3_kirana"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_door"]
size = Vector2(20, 80)
'''
    for idx, (pos, sz) in enumerate(d['platforms']):
        content += f'''
[sub_resource type="RectangleShape2D" id="RectangleShape2D_plat_{idx}"]
size = Vector2({sz[0]}, {sz[1]})
'''
    content += f'''
[node name="{r_name}" type="Node2D"]
script = ExtResource("1_room")
room_id = "{d['id']}"
next_room_id = "{d['next']}"
prev_room_id = "{d['prev']}"

[node name="Background" type="Sprite2D" parent="."]
texture_filter = 1
position = Vector2(240, 135)
scale = Vector2(0.175, 0.175)
texture = ExtResource("2_bg")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(240, 135)
zoom = Vector2(4, 4)

[node name="SpawnLeft" type="Marker2D" parent="."]
position = Vector2(40, 230)

[node name="SpawnRight" type="Marker2D" parent="."]
position = Vector2(440, 230)

[node name="ExitRight" type="Area2D" parent="."]
position = Vector2(475, 210)
collision_layer = 0
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitRight"]
shape = SubResource("RectangleShape2D_door")
'''
    if d['prev'] != '':
        content += f'''
[node name="ExitLeft" type="Area2D" parent="."]
position = Vector2(5, 210)
collision_layer = 0
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitLeft"]
shape = SubResource("RectangleShape2D_door")
'''
    for idx, (pos, sz) in enumerate(d['platforms']):
        content += f'''
[node name="Platform_{idx}" type="StaticBody2D" parent="."]
position = Vector2({pos[0]}, {pos[1]})
collision_layer = 1
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="Platform_{idx}"]
shape = SubResource("RectangleShape2D_plat_{idx}")
'''
    content += f'''
[node name="Kirana" parent="." instance=ExtResource("3_kirana")]
position = Vector2(40, 230)
'''
    Path(f"scenes/rooms/{r_name}.tscn").write_text(content, encoding="utf-8")
    print(f"Generated {r_name}.tscn")
