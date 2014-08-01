db = require "./db"

exports.getLatestDate = (callback) ->
	db.Module.find {}
	.sort
		date: -1
	.limit 1
	.exec (err, res) ->
		return callback err if err?
		date = (res[0]).date
		return callback null, date

exports.getYesterdayDate = (callback) ->
	db.Module.find {}
	.sort
		date: -1
	.limit 2
	.exec (err, res) ->
		return callback err if err?
		date = (res[1]).date
		return callback null, date

exports.getAllDates = (callback) ->
	db.Module.distinct 'date'
	, (err, dates) ->
		return callback err if err?
		return callback null, dates

exports.getAllModules = (callback) ->
	db.Module.distinct 'name'
	, (err, modules) ->
		return callback err if err?
		return callback null, modules

exports.getAllTestName = (callback) ->
	db.Test.distinct 'name'
	, (err, tests) ->
		return callback err if err?
		return callback null, tests


###
	APIs to get the details about the modules.
###

exports.getModuleById = (moduleId, callback) ->
	db.Module.find
		_id: moduleId
	, (err, module) ->
		return callback err if err?
		return callback null, module

exports.getModulesByName = (name, callback) ->
	db.Module.find
		name: name
	, (err, modules) ->
		return callback err if err?
		return callback null, modules

exports.getModulesByDate = (date, callback) ->
	db.Module.find 
		date: date
	, (err, modules) ->
		return callback err if err?
		return callback null, modules

exports.getModuleByNameAndDate = (name, date, callback) ->
	db.Module.find
		name: name
		date: date
	, (err, module) ->
		return callback err if err?
		return callback null, module

exports.getModulesByOwner = (owner, callback) ->
	db.Module.find
		owner: owner
	, (err, modules) ->
		return callback err if err?
		return callback null, modules

exports.getPassedCountByModule = (moduleId, callback) ->
	db.Test.count 
		module: moduleId
		status: /^passed$/i
	, (err, passed) ->
		return callback err if err?
		return callback null, passed

exports.getFailedCountByModule = (moduleId, callback) ->
	db.Test.count 
		module: moduleId
		status: /^failed$/i
	, (err, failed) ->
		return callback err if err?
		return callback null, failed

exports.getIndeterminateCountByModule = (moduleId, callback) ->
	db.Test.count 
		module: moduleId
		status: /^indeterminate$/i
	, (err, indeterminate) ->
		return callback err if err?
		return callback null, indeterminate


###
	APIs to get the details about Tests.
###

exports.getTestById = () ->
	

exports.getTestsByModule = (moduleId, callback) ->
	db.Test.find 
		module: moduleId
	, (err, tests) ->
		return callback err if err?
		return callback null, tests

exports.getTestsByName = () ->


exports.getTestsByStatus = () ->


exports.getTestsByNameAndStatus = () ->


exports.getTestByModuleAndName = () ->


exports.getTestsByModuleAndStatus = () ->


