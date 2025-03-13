extends Control

@export var file_dialog:FileDialog
@export var save_dialog:FileDialog

@export var audio_player:AudioStreamPlayer

@export_group("UI Nodes")
@export var music_list_sorter:VBoxContainer
@export var playlist_list_sorter:VBoxContainer
@export var current_playlist_list_sorter:VBoxContainer
@export var current_playlist_directory_label:Label
@export var previous_file_contents:RichTextLabel
@export var new_file_contents:RichTextLabel
@export_group("UI Nodes/Panels")
@export var rename_panel:Panel
@export var confirm_save_panel:Panel
@export_group("UI Nodes/Buttons")
@export var actionmenu_save_playlist:Button
@export var actionmenu_saveas_button:Button
@export var actionmenu_rename_button:Button
@export var actionmenu_reset_playlist_button:Button
@export var actionmenu_reload_button:Button
@export_group("UI Nodes/Player")
@export var player_parent:MarginContainer
@export var play_pause_button:Button
@export var stop_button:Button
@export var playing_song_name_label:Label
@export var duration_slider:HSlider
@export var duration_label:Label
@export var previous_button:Button
@export var next_button:Button

@export_group("Scenes")
@export var song_row:PackedScene
@export var playlist_row:PackedScene
@export var playlist_song_row:PackedScene

@export_group("Fine Tune")
@export var allowed_song_extensions:Array[String]
@export var allowed_playlist_extensions:Array[String]

var directory:DirAccess #Directory to use
var directory_path:String:
	set(new_path):
		directory_path = new_path
		
		# Enable the buttons
		actionmenu_saveas_button.disabled = false

var current_playlist_path:String: #Playlist being read from
	set(new_path):
		current_playlist_path = new_path
		current_playlist_directory_label.text = current_playlist_path.get_file()
		
		#We can finally save.
		actionmenu_rename_button.disabled = false
		actionmenu_save_playlist.disabled = false
		actionmenu_reset_playlist_button.disabled = false
		actionmenu_reload_button.disabled = false
		

var virtual_playlist_copy:String: #A copy of the playlist to be used.
	set(new_text):
		print("-----"+"\n"+new_text+"\n"+"-----")
		virtual_playlist_copy = new_text
		
		clear_current_playlist()
		refresh_current_playlist()
var virtual_playlist_as_list:Array:
	get:
		return Array(virtual_playlist_copy.split("\n"))

func _ready():
	file_dialog.current_file = "playlist.m3u"

func _process(_delta):
	if not player_slider_being_dragged:
		duration_label.text = Time.get_time_string_from_unix_time(int(audio_player.get_playback_position()))
		duration_slider.value = audio_player.get_playback_position()

func refresh_all():
	#Start by clearing everything
	clear_all_playlists()
	clear_all_songs()
	clear_current_playlist()
	
	refresh_songs()
	refresh_playlists()

#region Audio Player
func playpause_audio():
	audio_player.stream_paused = !audio_player.stream_paused


var playing_song_name:String
func play_song(file_name:String):
	player_parent.show()
	
	if file_name.get_extension() == "mp3":
		var song_file = FileAccess.open(directory_path+"/"+file_name,FileAccess.READ)
		
		
		audio_player.stream = AudioStreamMP3.new() #Make a new empty stream
		audio_player.stream.data = song_file.get_buffer(song_file.get_length()) #Dump the data
		song_file.close()
		
		audio_player.play()
		playing_song_name = file_name
		
		# Set labels and other variables
		duration_slider.max_value = audio_player.stream.get_length()
		playing_song_name_label.text = file_name

func skip_song():
	var directory_list:Array = Array(directory.get_files())
	for file_name in directory_list:
		if not allowed_song_extensions.has(file_name.get_extension()): #Remove non music stuff
			directory_list.erase(file_name)
		
	var current_file_index = directory_list.find(playing_song_name)
	
	# Makes sure we dont play an invalid file
	if current_file_index+1 <= directory_list.size()-1:
		var name_of_next_song = directory_list[current_file_index+1]
		print(name_of_next_song)
		play_song(name_of_next_song)

func unskip_song():
	var directory_list:Array = Array(directory.get_files())
	for file_name in directory_list:
		if not allowed_song_extensions.has(file_name.get_extension()): #Remove non music stuff
			directory_list.erase(file_name)
			
	var current_file_index = directory_list.find(playing_song_name)
	
	if current_file_index-1 <= directory_list.size()-1:
		var name_of_previous_song = directory_list[current_file_index-1]
		play_song(name_of_previous_song)

func stop_music():
	player_parent.hide()
	audio_player.stop()

var player_slider_being_dragged:bool
func drag_started():
	player_slider_being_dragged = true
func drag_ended(_value_changed:bool):
	player_slider_being_dragged = false
func player_slider_set_value(value:float):
	if player_slider_being_dragged:
		audio_player.seek(value)

func _on_audio_finished():
	audio_player.play()
	audio_player.set_stream_paused(true)
#endregion
#region Buttons
func _on_file_dialog_dir_selected(dir_path):
	directory = DirAccess.open(dir_path)
	directory_path = dir_path
	
	refresh_all()


var saving_playlist_path:String #A temporary path of the new playlist
func _on_save_dialog_file_selected(new_file_path):
	saving_playlist_path = new_file_path
	
	# Export the file
	_on_save_pressed()

func _on_save_pressed():
	if not saving_playlist_path == current_playlist_path:
		confirm_save_panel.show()
		new_file_contents.text = virtual_playlist_copy
		#Prevents crash when a new playlist is being saved.
		if FileAccess.file_exists(saving_playlist_path):
			previous_file_contents.text = FileAccess.open(saving_playlist_path,FileAccess.READ).get_as_text()
	else: #No Playlist so make a new one
		_on_save_confirmed()
func _on_save_confirmed():
	var file = FileAccess.open(saving_playlist_path,FileAccess.WRITE_READ)
	file.store_string(virtual_playlist_copy.trim_prefix("\n")) #Sanitize output
	file.close()
	confirm_save_panel.hide()
	
	current_playlist_path = saving_playlist_path
	open_playlist(saving_playlist_path.get_file())
	#refresh_all()

func _rename_submitted(new_name:String):
	rename_panel.hide()
	if current_playlist_path == "": #No playlist so no point in renaming
		return 
	else:
		var file_extension = current_playlist_path.get_extension()
		var new_file_path = directory_path+"/"+new_name+"."+file_extension
		directory.rename(current_playlist_path,new_file_path)
		
		# Set the new playlist to be the current one.
		current_playlist_path = new_file_path
		# Refresh everything
		refresh_all()

func _quit():
	get_tree().quit()

func reset_current_playlist():
	virtual_playlist_copy = ""
	refresh_all()
func reload_current_playlist():
	open_playlist(current_playlist_path.get_file())
#endregion
#region Management
func open_playlist(playlist_name:String):
	var playlist_path:String = directory_path+"/"+playlist_name
	current_playlist_path = playlist_path #For later reference
	
	var file = FileAccess.open(playlist_path,FileAccess.READ)
	
	virtual_playlist_copy = file.get_as_text().trim_suffix("\n") #Stores it in our copy

func remove_song(song_index:int):
	var temp_playlist = virtual_playlist_as_list.duplicate()
	temp_playlist.remove_at(song_index)
	
	virtual_playlist_copy = "" #Empty it out
	for line in temp_playlist:
		virtual_playlist_copy += line+"\n"

func add_song(song_name:String):
	virtual_playlist_copy = virtual_playlist_copy.trim_suffix("\n") #Cleanup
	virtual_playlist_copy += "\n"+song_name

func move_song(from:int,to:int):
	# Moves song from the index "from" to the index "to"
	var song_to_be_moved = virtual_playlist_as_list[from]
	# Remove song at the index
	var temp_playlist = virtual_playlist_as_list.duplicate()
	temp_playlist.remove_at(from)
	
	# Add song at the index
	temp_playlist.insert(clampi(to,0,99999),song_to_be_moved)
	
	virtual_playlist_copy = "" #Empties it out and adds it back in at the index
	for song in temp_playlist:
		virtual_playlist_copy += song+"\n"
#endregion
#region Add Entries to Visual Space
func refresh_songs():
	for file_name in directory.get_files():
		if allowed_song_extensions.has(file_name.get_extension()):
			var new_song_row = song_row.instantiate()
			
			new_song_row.get_node("Label").text = file_name
			new_song_row.get_node("Play").pressed.connect(play_song.bind(file_name))
			new_song_row.get_node("Add").pressed.connect(add_song.bind(file_name))
			
			music_list_sorter.add_child(new_song_row)

func refresh_playlists():
	for file_name in directory.get_files():
		if allowed_playlist_extensions.has(file_name.get_extension()):
			var new_playlist_row = playlist_row.instantiate()
			
			new_playlist_row.get_node("Label").text = file_name
			new_playlist_row.get_node("Open").pressed.connect(open_playlist.bind(file_name))
			
			playlist_list_sorter.add_child(new_playlist_row)

func refresh_current_playlist():
	for line_index in virtual_playlist_as_list.size(): #Breaks it into lines
		var line_text = virtual_playlist_as_list[line_index]
		
		if not line_text == "": #Removes empty lines for neatness
			var new_song_name = playlist_song_row.instantiate()
			
			new_song_name.get_node("Label").text = line_text
			new_song_name.get_node("Trash").pressed.connect(remove_song.bind(line_index))
			new_song_name.get_node("Up").pressed.connect(move_song.bind(line_index,line_index-1))
			new_song_name.get_node("Down").pressed.connect(move_song.bind(line_index,line_index+1))
			
			current_playlist_list_sorter.add_child(new_song_name)
#endregion
#region Clear All Unused
func clear_all_songs():
	for child in music_list_sorter.get_children():
		child.queue_free()
func clear_all_playlists():
	for child in playlist_list_sorter.get_children():
		child.queue_free()
func clear_current_playlist():
	for child in current_playlist_list_sorter.get_children():
		child.queue_free()
#endregion
