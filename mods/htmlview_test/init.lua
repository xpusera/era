htmlview.run("test_ui", [[
<!DOCTYPE html>
<html>
<body style="background:rgba(0,0,0,0.5); display:flex; justify-content:center; align-items:center;">
  <button onclick="luanti.send('teleport')" 
          style="padding:20px; font-size:24px; color:white; background:#333;">
    Teleport Me
  </button>
</body>
<script>
  luanti.on_message(function(msg) {
    document.body.style.background = msg === 'red' ? 'rgba(255,0,0,0.5)' : 'rgba(0,0,0,0.5)';
  });
</script>
</html>
]])

htmlview.display("test_ui", {
	visible = true,
	x = 50,
	y = 50,
	width = 400,
	height = 200,
	safe_area = true
})

htmlview.on_message("test_ui", function(msg)
	if msg == "teleport" then
		local players = minetest.get_connected_players()
		local player = players[1]
		if player then
			player:set_pos({x = math.random(-100, 100), y = 10, z = math.random(-100, 100)})
			htmlview.send("test_ui", "red")
		end
	end
end)
