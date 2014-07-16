mongoose = require "mongoose"

mongoose.connect "mongodb://dsw-vnc-016.cisco.com:27017/bodega"

mongoose.connection.on 'error',  ->
	throw "MongoDB connection error"

exports.Module = mongoose.model "Module",
	module: String

exports.Test = mongoose.model "Test",
	module: String
	date: Date
	testName: String
	status: String
	rtlBuildLog: String
	buildLog: String
	simulationLog: String
	buildErrors: Number
	buildWarnings: Number
	simulationErrors: Number
	simulationWarnings: Number
	reg2AttrTotal: Number
	reg2AttrPassed: Number
	reg2AttrFailed: Number
	owner: String
