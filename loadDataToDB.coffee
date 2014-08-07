db = require "./db"
fs = require "fs"
path = require 'path'
async = require 'async'
argv = require('optimist').argv

parentDir = (argv.dir).replace /\/*$/, ''
parentDir += '/'

finder = require('findit')(parentDir)

fileToFind = argv.file
filePaths = []
delay = argv.delay


findFiles = (parentDir, fileToFind, callback) ->
	finder.on 'file', (file) ->
		fileName = path.basename file
		if fileName is fileToFind
			return callback file, null, null
	finder.on 'end', () ->
		return callback null, 1, null
	finder.on 'error', (err) ->
		return callback null, null, err


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
			console.log modelCol.date + ' : ' + modelCol.name + ' : Error'
			return callback err
		else
			n = (testCol.name).length
			n -= 1
			if n < 0
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
				console.log modelCol.date + ' : ' + modelCol.name + ' : Error'
				return callback noError
			else
				return callback null


readFiles = (file, callback) ->
	first = 0
	prjSrc = ''
	modelCol = {}
	testCol = {}
	fs.readFile file, (err, data) -> 
		if err?
			return callback err
		else
			fileText = data.toString()
			lines = fileText.split("\n")
			for line in lines
				line = line.trim()
				if line.indexOf('PROJ_SRC_ROOT') > -1
					prjSrc = line.match /^PROJ_SRC_ROOT\s*\=(.*)$/
					prjSrc = (prjSrc[1]).trim()
					if first != 0
						writeToDb modelCol, testCol, (err1) ->
							if err1?
								return callback err1
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
					first = 1
				if line.indexOf('PROJ_GEN_ROOT') > -1
					prjGen = line.match /^PROJ_GEN_ROOT\s*\=(.*)$/
					prjGen = (prjGen[1]).trim()
					prjSrc = prjSrc.replace /src/g, 'gen'
					name = prjGen.replace prjSrc, ''
					name = name.replace /^\/*/, ''
					date = line.match /(\d\d\.\d\d\.\d\d\d\d\.\d\d\.\d\d)/
					modelCol.date = date[1]
					modelCol.name = name
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
			if first != 0
				writeToDb modelCol, testCol, (err2) ->
					return callback err2
			else
				return callback null


extractData = (filePaths, done) ->
	async.eachSeries filePaths
	, (file, callback) ->
		readFiles file, (err) ->
			callback err
	, (error) ->
		if error?
			return done error
		else
			return done null


findFiles parentDir, fileToFind, (file, status, err) ->
	if err?
		console.log err
		console.log "Fail"
		process.exit 1
	else if status?
		extractData filePaths, (error) ->
			if error?
				console.log error
				console.log "Fail"
				process.exit 1
			else
				setTimeout (() -> process.exit(0)), 15000
	else
		filePaths.push file


#Command to get Latest Run Details: coffee loadDataToDB.coffee --dir='/users/regress/uregress/bodega.latest' --file='results.log'
#Command to get Yesterday's Run Details: coffee loadDataToDB.coffee --dir='/users/regress/uregress/bodega.yesterday' --file='results.log'
#Command to get all details from Archive: coffee loadDataToDB.coffee --dir='/users/regress/archives/bodega/' --file='results.log'