db = require "./db"
fs = require "fs"
path = require 'path'
async = require 'async'

parentDir = process.argv[2].replace /\/*$/, ''
parentDir += '/'

finder = require('findit')(parentDir)

fileToFind = process.argv[3]
filePaths = {}


findFiles = (parentDir, fileToFind, callback) ->
	finder.on 'file', (file) ->
		fileName = path.basename file
		dirName = path.dirname file
		dirNameOfDir = path.dirname dirName
		lastDir = dirNameOfDir.slice(-4)
		dateTemp = dirName.replace parentDir, ''
		date = dateTemp.replace /\/.*$/, ''
		if fileName is fileToFind && lastDir is '/env'
			return callback date, file, null, null
	finder.on 'end', () ->
		return callback null, null, 1, null
	finder.on 'error', (err) ->
		return callback null, null, null, err


writeToDb = (modelCol, testCol, callback) ->
	db.Module.findOneAndUpdate {name: modelCol.name, date: modelCol.date},
		name: modelCol.name
		date: modelCol.date
		elapsedTime: modelCol.time
		owner: modelCol.owner
		reg2AttrTotal: modelCol.attrTotal
		reg2AttrPassed: modelCol.attrPassed
		reg2AttrFailed: modelCol.attrFailed
	, upsert: true, new: true
	, (err, resp) ->
		if err?
			return callback err
		else
			n = (testCol.name).length
			n -= 1
			if n <= 0?
				return callback null
			for i in [0..n]
				db.Test.findOneAndUpdate {module: resp._id, name: testCol.name[i]},
					module: resp._id
					name: testCol.name[i]
					status: testCol.status[i]
					rtlBuildLog: 
						path: testCol.rtlPath[i]
					buildLog: 
						path: testCol.bldPath[i]
						errors: testCol.bldErr[i]
						warnings: testCol.bldWarn[i]
					simulationLog: 
						path: testCol.simPath[i]
						errors: testCol.simErr[i]
						warnings: testCol.simWarn[i]
					#runtime: testCol.time[i]
					#seed: testCol.seed[i]
				, upsert: true, new: true
				, (err1, res) ->
					if err1?
						console.log modelCol
						console.log testCol
						console.log err1
			console.log modelCol.date + '/' + modelCol.name + ' : Completed'
			return callback null


readFiles = (file, callback) ->
	#console.log file
	modelCol = {}
	modelCol.name = null
	modelCol.date = null
	modelCol.time = null
	modelCol.owner = null
	modelCol.attrTotal = null
	modelCol.attrPassed = null
	modelCol.attrFailed = null
	testCol = {}
	testCol.status = []
	testCol.name = []
	testCol.time = []
	testCol.seed = []
	testCol.rtlPath = []
	testCol.bldPath = []
	testCol.bldErr = []
	testCol.bldWarn = []
	testCol.simPath = []
	testCol.simErr = []
	testCol.simWarn = []
	dirName = path.dirname file
	dateTemp = dirName.replace parentDir, ''
	date = dateTemp.replace /\/.*$/, ''
	modelName = dateTemp.replace date+'/', ''
	modelCol.name = modelName
	modelCol.date = date
	fs.readFile file, (err, data) -> 
		if err?
			return callback err
		else
			fileText = data.toString()
			lines = fileText.split("\n")
			for line in lines
				if line.indexOf('==>Elapsed Time=') > -1
					elapsedTime = line.match /\'(.*)\'/
					modelCol.time = elapsedTime[1]
				if line.indexOf('OWNER') > -1
					owner = line.match /\=(.*)$/
					modelCol.owner = owner[1]
				if line.indexOf('Reg2Attr') > -1
					total = line.match /Total\=(.*)\,Passed/
					passed = line.match /Passed\=(.*)\,Failed/
					failed = line.match /Failed\=(.*)$/
					modelCol.attrTotal = Number(total[1])
					modelCol.attrPassed = Number(passed[1])
					modelCol.attrFailed = Number(failed[1])
				if line.indexOf('=>TEST') > -1
					status = line.match /^=>TEST *([A-Z]+) * \'.*\'.*$/
					name = line.match /^=>TEST *[A-Z]+ * \'(.*)\'.*$/
					(testCol.status).push status[1]
					(testCol.name).push name[1]
				if line.indexOf('=>RUNTIME') > -1
					runTime = line.match /^=>RUNTIME *\'(.*)\' *\'.*\'$/
					(testCol.time).push runTime[1]
				if line.indexOf('=>SEED') > -1
					seed = line.match /^=>SEED *\'(.*)\'.*$/
					(testCol.seed).push Number(seed[1])
				if line.indexOf('==RTL build log') > -1
					rtl = line.match /^==RTL build log\: *(.*)$/
					(testCol.rtlPath).push rtl[1]
				if line.indexOf('==Build log') > -1
					bld = line.match /^==Build log\: *(.*) +\(/
					bldErr = line.match /\(Errors=(.*)\,Warnings=.*\)/
					bldWarn = line.match /\(Errors=.*\,Warnings=(.*)\)/
					(testCol.bldPath).push bld[1]
					(testCol.bldErr).push Number(bldErr[1])
					(testCol.bldWarn).push Number(bldWarn[1])
				if line.indexOf('==Simulation log') > -1
					sim = line.match /^==Simulation log\: *(.*) +\(/
					simErr = line.match /\(Errors=(.*)\,Warnings=.*\)/
					simWarn = line.match /\(Errors=.*\,Warnings=(.*)\)/
					(testCol.simPath).push sim[1]
					(testCol.simErr).push Number(simErr[1])
					(testCol.simWarn).push Number(simWarn[1])
			writeToDb modelCol, testCol, (err1) ->
				return callback err1


extractData = (filePaths, done) ->
	dates = []
	for date in Object.keys(filePaths)
		dates.push date if dates.indexOf(date) is -1
	dates.sort()
	#top10Dates = dates.slice(Math.max(dates.length - 10, 1))
	top10Dates = dates
	files = []
	for date in top10Dates
		for file in filePaths[date]
			files.push file if files.indexOf(file) is -1
	async.eachLimit files, 10
	, (file, callback) ->
		readFiles file, (err) ->
			callback err
	, (error) ->
		if error?
			return done error
		else
			return done null


findFiles parentDir, fileToFind, (date, file, status, err) ->
	if err?
		console.log err
	else if status?
		extractData filePaths, (error) ->
			if error?
				console.log error
				console.log "Fail"
				process.exit 1
			else
				console.log "Success"
				#process.exit 0
	else
		if filePaths[date]?
			(filePaths[date]).push file
		else
			filePaths[date] = []
			(filePaths[date]).push file


