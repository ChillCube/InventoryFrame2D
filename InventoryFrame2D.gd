extends SpritePlacement2D
class_name InventoryFrame2D

@export var inventory : Inventory;
@export var slot : int;
@export var number_source : NumberResource;

var item_being_moved : bool = false;
var item : PlaceableItem2D;

func _ready() -> void:
	accepted_classes = ["PlaceableItem2D"]
	add_to_group("inventory_frame_2d")
	super();
	if inventory == null:
		push_error("InventoryFrame2D: 'inventory' is not assigned on slot %d. Set it in the Inspector." % slot);
		return;
	var inv_item = inventory.get_item_at(slot);
	if inv_item != null:
		_spawn_item(inv_item);
	placement.object_snapped.connect(_on_item_snapped);

func _spawn_item(inv_item: Item) -> void:
	var new_item_object : PlaceableItem2D = PlaceableItem2D.new()
	new_item_object.item = inv_item;
	new_item_object.number_source = number_source;
	new_item_object.count = inventory.get_count_at(slot);
	placement.add_child(new_item_object);
	placement.held_objects.append(new_item_object);
	new_item_object.just_picked_up.connect(func(_pos): placement.held_objects.erase(new_item_object));
	new_item_object.dragger.object_placed.connect(func():
		if new_item_object.get_parent() == placement and is_instance_valid(new_item_object) and new_item_object not in placement.held_objects:
			placement.held_objects.append(new_item_object));
	new_item_object.just_picked_up.connect(_on_picked_up);
	new_item_object.just_placed.connect(_on_place);
	item = new_item_object;
	print("[Slot %d] Spawned item: %s x%d" % [slot, inv_item.name, new_item_object.count]);

func _on_item_snapped(obj: Node2D) -> void:
	if not obj is PlaceableItem2D or obj == item:
		return;
	var incoming := obj as PlaceableItem2D;
	if is_instance_valid(item) and item.item != incoming.item:
		push_warning("[Slot %d] Type mismatch on snap: ejecting %s (slot holds %s)" % [slot, incoming.item.name, item.item.name]);
		_eject_item(incoming);
		return;
	item = incoming;
	inventory.set_slot(slot, item.item, item.count);
	if not item.just_picked_up.is_connected(_on_picked_up):
		item.just_picked_up.connect(_on_picked_up);
	if not item.just_placed.is_connected(_on_place):
		item.just_placed.connect(_on_place);
	print("[Slot %d] Received item: %s x%d" % [slot, item.item.name, item.count]);

func _eject_item(obj: PlaceableItem2D) -> void:
	placement.held_objects.erase(obj);
	obj.reparent(get_tree().current_scene, true);
	obj.is_in_placement_area = false;

func _process(_delta: float) -> void:
	if not is_instance_valid(item):
		return;
	for child in placement.get_children():
		if child is PlaceableItem2D and child != item and child.item != item.item:
			push_warning("[Slot %d] Failsafe triggered: ejecting mismatched item %s" % [slot, child.item.name]);
			_eject_item(child);

func try_receive_single(incoming_item: Item) -> bool:
	if inventory == null:
		return false
	if is_instance_valid(item):
		if item.item != incoming_item:
			return false
		item.count += 1
		inventory.set_slot(slot, item.item, item.count)
		return true
	# Empty frame: ensure the inventory slot exists, then spawn with count=1
	while inventory.items.size() <= slot:
		inventory.items.append(null)
		inventory.counts.append(0)
	inventory.set_slot(slot, incoming_item, 1)
	_spawn_item(incoming_item)
	return true

func _on_picked_up(_position : Vector2):
	item_being_moved = true;
	print("[Slot %d] Item picked up" % slot);

func _on_place(_position : Vector2):
	item_being_moved = false;
	if item == null:
		return;
	if item.get_parent() == placement:
		print("[Slot %d] Item returned to slot: %s x%d" % [slot, item.item.name, item.count]);
	elif item.get_parent() is PlacementArea2D:
		inventory.set_slot(slot, null);
		item = null;
		print("[Slot %d] Slot cleared" % slot);
	else:
		# Item was ejected to scene root — re-adopt it so slot stays valid
		item.reparent(placement, true);
		if item not in placement.held_objects:
			placement.held_objects.append(item);
		inventory.set_slot(slot, item.item, item.count);
		print("[Slot %d] Item ejected and re-adopted: %s x%d" % [slot, item.item.name, item.count]);
