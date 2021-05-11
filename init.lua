nametags = {
	nametag_cache = {},
	item_texture_cache = {},
	armor_cache = {},
}

function nametags.get_wield_entity(player)
	for _, child in pairs(minetest.get_objects_inside_radius(player:get_pos(), 1)) do
		if child:get_attach() == player then
			local child_prop = child:get_properties()
			if child_prop.visual == "wielditem" then
				return child
			end
		end
	end
end

function nametags.resize_image(image)
	return image .. "^[resize:32x32"
end

function nametags.colorize_tiledef(tile, node_color)
	if tile.name == "" then
		return
	end

	local color = tile.color or node_color
	if color then
		return "(" .. tile.name .. ")^[multiply:" .. minetest.rgba(color.r, color.g, color.b, color.a)
	else
		return tile.name
	end
end

function nametags.render_tile(nodedef, n)
	local img = nametags.colorize_tiledef(nodedef.tiles[n], nodedef.color)
	local overlay = nametags.colorize_tiledef(nodedef.overlay_tiles[n], nodedef.color)

	if overlay then
		img = img .. "^(" .. overlay .. ")"
	end

	return img
end

function nametags.create_item_texture(itemname)
	local itemdef = minetest.get_item_def(itemname)
	local nodedef = minetest.get_node_def(itemname)
	if itemdef then
		if itemdef.inventory_image ~= "" then
			return itemdef.inventory_image
		elseif nodedef then
			if nodedef.drawtype == "mesh" or nodedef.drawtype == "nodebox" then
				return nodedef.tiles[1].name
			else
				return minetest.inventorycube(
					nametags.render_tile(nodedef, 1),
					nametags.render_tile(nodedef, 6),
					nametags.render_tile(nodedef, 5)
				)
			end
		end
	end
end

function nametags.get_item_texture(itemname)
	local cached_texture = nametags.item_texture_cache[itemname]
	if cached_texture then
		return cached_texture
	end
	local texture = nametags.create_item_texture(itemname)
	nametags.item_texture_cache[itemname] = texture
	return texture
end

function nametags.parse_armor_texture(armor_texture)
	if armor_texture == "blank.png" then
		return {}
	end
	local armor_pieces = {}
	local armor_textures = armor_texture:sub(2, #armor_texture - 1):split(")^(")
	for _, texture in ipairs(armor_textures) do
		local itemname = nametags.armor_cache[texture]
		if not itemname then
			local piece_textures = texture:split("^")
			local enchanted = false
			if #piece_textures > 1 and piece_textures[2] == "[colorize:purple:50" then
				enchanted = true
			end
			local components = (piece_textures[1] or ""):split("_")
			local modname = table.remove(components, 1) or ""
			if modname then
				if modname == "mcl" then
					modname = modname .. "_" .. (table.remove(components, 1) or "")
				end
				local subname = table.concat(components, "_"):split(".")[1]
				itemname = modname .. ":" .. subname
				if enchanted then
					itemname = itemname .. "_enchanted"
				end
			end
			nametags.armor_cache[texture] = itemname
		end
		table.insert(armor_pieces, 1, itemname)
	end
	return armor_pieces
end

function nametags.wield_entity_get_itemname(obj)
	local prop = obj and obj:get_properties()
	return prop and prop.textures[1] or ""
end

local blank_resized = nametags.resize_image("blank.png")

function nametags.update_nametag(player)
	if player:is_player() and not player:is_local_player() then
		local props = player:get_properties()

		local nametag = props.nametag
		local hp = player:get_hp()

		local idx = nametag:find("♥")

		if idx then
			nametag = nametag:sub(1, idx + 2) .. hp
		else
			nametag = nametag .. minetest.get_color_escape_sequence("#FF0000") .. " ♥" .. hp
		end

		player:set_properties({
			nametag = nametag,
			nametag_bgcolor = {a = 128, r = 0, g = 0, b = 0}
		})

		local cache = nametags.nametag_cache[player]

		if not cache then
			cache = {
				armor_texture = "blank.png",
				armor_textures = {},
				wield_texture = "blank.png",
				wield_texture_resized = blank_resized,
				wield_entity_itemname = "",
				wield_entity = nametags.get_wield_entity(player),
				nametag_images = {blank_resized},
			}
			nametags.nametag_cache[player] = cache
		end

		local wield_texture = props.textures[3]
		local wield_texture_blank = wield_texture == "blank.png"
		local wield_entity_itemname = ""
		local wield_cached = cache.wield_texture == wield_texture

		if wield_texture_blank then
			wield_entity_itemname = nametags.wield_entity_get_itemname(cache.wield_entity)
			wield_cached = wield_cached and cache.wield_entity_itemname == wield_entity_itemname
		end

		local armor_texture = props.textures[2]
		local armor_cached = cache.armor_texture == armor_texture

		local nametag_images

		if wield_cached and armor_cached then
			nametag_images = cache.nametag_images
		else
			local wield_texture_resized

			if wield_cached then
				wield_texture_resized = cache.wield_texture_resized
			else
				if wield_texture_blank then
					if wield_entity_itemname ~= "" then
						wield_texture = nametags.get_item_texture(wield_entity_itemname) or "blank.png"
					end
				end
				wield_texture_resized = nametags.resize_image(wield_texture)
				cache.wield_texture = wield_texture
				cache.wield_texture_resized = wield_texture_resized
			end

			local armor_textures

			if armor_cached then
				armor_textures = cache.armor_textures
			else
				armor_textures = {}
				for _, piece in ipairs(nametags.parse_armor_texture(armor_texture)) do
					local texture = nametags.get_item_texture(piece)
					if texture then
						table.insert(armor_textures, nametags.resize_image(texture))
					end
				end
				cache.armor_texture = armor_texture
				cache.armor_textures = armor_textures
			end

			nametag_images = {wield_texture_resized}
			for _, texture in ipairs(armor_textures) do
				table.insert(nametag_images, texture)
			end
			cache.nametag_images = nametag_images
		end

		player:set_nametag_images(nametag_images)
	end
end

minetest.register_on_object_properties_change(nametags.update_nametag)
minetest.register_on_object_hp_change(nametags.update_nametag)

minetest.register_on_object_add(function(obj)
	local attach = obj:get_attach()
	if attach and attach:is_player() and not attach:is_local_player() then
		local cache = nametags.nametag_cache[attach]

		if cache then
			cache.wield_entity = obj
		end
	end
end)
