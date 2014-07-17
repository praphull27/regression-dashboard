mongoose = require "mongoose"

mongoose.connect "mongodb://dsw-vnc-016.cisco.com:27017/bodega"

mongoose.connection.on 'error',  ->
	throw "MongoDB connection error"

exports.Module = mongoose.model "Module",
	name: String
	date: String
	owner: String
	elapsedTime: String
	reg2AttrTotal: Number
	reg2AttrPassed: Number
	reg2AttrFailed: Number


exports.Test = mongoose.model "Test",
	module: type: mongoose.Schema.ObjectId, ref: "Module"
	name: String
	status: String
	rtlBuildLog: 
		path: String
	buildLog: 
		path: String
		errors: Number
		warnings: Number
	simulationLog: 
		path: String
		errors: Number
		warnings: Number
	runtime: String
	seed: Number

