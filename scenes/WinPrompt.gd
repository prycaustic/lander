extends Panel

func _ready():
	set_visible(false)
	Events.connect("explode", _on_lose)
	Events.connect("win", _on_win)
	
func _on_lose():
	set_visible(true)
	
func _on_win():
	$Label.text = "SAFELY LANDED!"
	set_visible(true)
