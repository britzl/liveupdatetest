local M = {}

M.log = print

local function log(...)
	M.log(...)
end

local function get_metadata_filename()
	return sys.get_save_file(sys.get_config("project.title"), "liveupdate_meta")
end

local function load_metadata()
	return sys.load(get_metadata_filename())
end

local function checksum(buffer)
	return hash_to_hex(hash(buffer))
end

local function status_to_string(status)
	if status == resource.LIVEUPDATE_OK then
		return "LIVEUPDATE_OK"
	elseif status == resource.LIVEUPDATE_INVALID_RESOURCE then
		return "LIVEUPDATE_INVALID_RESOURCE"
	elseif status == resource.LIVEUPDATE_ENGINE_VERSION_MISMATCH then
		return "LIVEUPDATE_ENGINE_VERSION_MISMATCH"
	elseif status == resource.LIVEUPDATE_FORMAT_ERROR then
		return "LIVEUPDATE_FORMAT_ERROR"
	elseif status == resource.LIVEUPDATE_BUNDLED_RESOURCE_MISMATCH then
		return "LIVEUPDATE_BUNDLED_RESOURCE_MISMATCH"
	elseif status == resource.LIVEUPDATE_SCHEME_MISMATCH then
		return "LIVEUPDATE_SCHEME_MISMATCH"
	elseif status == resource.LIVEUPDATE_SIGNATURE_MISMATCH then
		return "LIVEUPDATE_SIGNATURE_MISMATCH"
	else
		return("UNKNOWN")
	end
end

local function download(url, cb)
	log("Downloading", url)
	http.request(url, "GET", function(self, id, response)
		if response.status ~= 200 then
			cb(nil, response)
			return
		end
		cb(response.response, response)
	end)
end


local config = {}

function M.init(server_url)
	config.server_url = server_url
end

function M.download_manifest(cb)
	local url = config.server_url .. "/liveupdate.game.dmanifest"
	log("Downloading manifest from", url)
	download(url, cb)
end

function M.store_manifest(manifest, cb)
	log("Storing manifest")
	local manifest_hex = checksum(manifest)
	log("Manifest hex", manifest_hex)
	local metadata = sys.load(get_metadata_filename())
	if metadata.manifest_hex == manifest_hex then
		log("LIVEUPDATE_OK - manifest already saved")
		cb(true)
		return
	end
	resource.store_manifest(manifest, function(self, status)
		log(status_to_string(status))
		if status == resource.LIVEUPDATE_OK then
			log("Stored manifest - rebooting!")
			metadata.manifest_hex = manifest_hex
			sys.save(get_metadata_filename(), metadata)
			sys.reboot()
		else
			cb(false)
		end
	end)
end

function M.update_manifest(cb)
	M.download_manifest(function(manifest, response)
		if not manifest then
			cb(false)
			return
		end
		M.store_manifest(manifest, cb)
	end)
end

local function load_and_store_missing_resource(resource_hash, cb)
	local url = config.server_url .. "/" .. resource_hash
	log("Downloading missing resource", url)
	download(url, function(resource_data, response)
		if resource_data then
			local manifest_reference = resource.get_current_manifest()
			resource.store_resource(manifest_reference, resource_data, resource_hash, function(self, hexdigest, status)
				log("Storing resource", url, status)
				cb(status)
			end)
		else
			cb(false)
		end
	end)
end


function M.load_missing_resources(proxy_url, cb)
	log("Load missing resources", proxy_url)
	local missing = collectionproxy.missing_resources(proxy_url)
	local progress = {
		total = #missing,
		loaded = 0,
		failed = 0,
		done = #missing == 0
	}
	pprint(missing)

	local load_missing = nil	
	load_missing = function()
		cb(progress)
		if not progress.done then
			local resource_hash = table.remove(missing)
			load_and_store_missing_resource(resource_hash, function(ok)
				if ok then
					progress.loaded = progress.loaded + 1
				else
					progress.failed = progress.failed + 1
				end
				progress.done = (progress.loaded + progress.failed) == progress.total
				load_missing()
			end)
		end
	end
	load_missing()
end

return M