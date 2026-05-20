extends SpritePlacement2D
class_name InventoryFrame2D

@export var inventory : Inventory;
@export var slot : int;

var item_being_moved : bool = false;
var item : PlaceableItem2D;

func _ready() -> void:
	accepted_classes = ["PlaceableItem2D"]
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
	placement.add_child(new_item_object);
	new_item_object.just_picked_up.connect(_on_picked_up);
	new_item_object.just_placed.connect(_on_place);
	item = new_item_object;
	print("[Slot %d] Spawned item: %s" % [slot, inv_item.name]);

func _on_item_snapped(obj: Node2D) -> void:
	if not obj is PlaceableItem2D or obj == item:
		return;
	item = obj as PlaceableItem2D;
	inventory.set_slot(slot, item.item);
	if not item.just_picked_up.is_connected(_on_picked_up):
		item.just_picked_up.connect(_on_picked_up);
	if not item.just_placed.is_connected(_on_place):
		item.just_placed.connect(_on_place);
	print("[Slot %d] Received item: %s" % [slot, item.item.name]);

func _on_picked_up(_position : Vector2):
	item_being_moved = true;
	print("[Slot %d] Item picked up" % slot);

func _on_place(_position : Vector2):
	item_being_moved = false;
	if item == null:
		return;
	if item.get_parent() == placement:
		inventory.set_slot(slot, item.item);
		print("[Slot %d] Item returned to slot: %s" % [slot, item.item.name]);
	else:
		inventory.set_slot(slot, null);
		item = null;
		print("[Slot %d] Slot cleared" % slot);
