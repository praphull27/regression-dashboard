db = require "./db"
fs = require "fs"
path = require 'path'
async = require 'async'

parentDir = process.argv[2].replace /\/*$/, ''
parentDir += '/'

finder = require('findit')(parentDir)

fileToFind = process.argv[3]
filePaths = {}

dateStart = process.argv[4]
dateEnd = process.argv[5]


findFiles = (parentDir, fileToFind, callback) ->
	now = new Date
	console.log now
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
	noError = null
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
			console.log modelCol.date + '/' + modelCol.name + ' : Error'
			return callback err
		else
			n = (testCol.name).length
			n -= 1
			if n < 0?
				console.log modelCol.date + '/' + modelCol.name + ' : Completed'
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
					runtime: testCol.time[i]
					seed: testCol.seed[i]
				, upsert: true, new: true
				, (err1, res) ->
					if err1?
						console.log modelCol
						console.log testCol
						console.log err1
						noError = err1
			if noError?
				console.log modelCol.date + '/' + modelCol.name + ' : Error'
				return callback noError
			else
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
				line = line.trim()
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
					(testCol.status).push (status[1]).toLowerCase()
					(testCol.name).push name[1]
					if (testCol.name).length != (testCol.time).length
						(testCol.time).push null
					if (testCol.name).length != (testCol.seed).length
						(testCol.seed).push null
					if (testCol.name).length != (testCol.rtlPath).length
						(testCol.rtlPath).push null
					if (testCol.name).length != (testCol.bldPath).length
						(testCol.bldPath).push null
						(testCol.bldErr).push null
						(testCol.bldWarn).push null
					if (testCol.name).length != (testCol.simPath).length
						(testCol.simPath).push null
						(testCol.simErr).push null
						(testCol.simWarn).push null
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
	dates.reverse()
	if dates.length == 0
		error = 'No Data found. Test Results for each day should be placed in ' + parentDir + '$TimeStamp$/*. For example ' + parentDir + '07.19.2014.22.00/*'
		return done error
	if dates.length < dateEnd
		dateEnd = dates.length
	if date.length < dateStart
		dateStart = dates.length
	if dateStart < 1 
		dateStart = 0
	else
		dateStart -= 1
	if dateEnd < 1 
		dateEnd = 0
	topDates = dates.slice(dateStart, dateEnd)
	#topDates = dates
	files = []
	for date in topDates
		for file in filePaths[date]
			files.push file if files.indexOf(file) is -1
	async.eachLimit files, 100
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
				now = new Date
				console.log now
				setTimeout (() -> process.exit(0)), 300000
	else
		if filePaths[date]?
			(filePaths[date]).push file
		else
			filePaths[date] = []
			(filePaths[date]).push file

