db = require "./db"
fs = require "fs"
path = require 'path'

parentDir = process.argv[2].replace /\/*$/, ''
parentDir += '/'

finder = require('findit')(parentDir)

fileToFind = process.argv[3]
filePaths = []

findFiles = (parentDir, fileToFind, callback) ->
	finder.on 'file', (file) ->
		fileName = path.basename file
		dirName = path.dirname file
		dirNameOfDir = path.dirname dirName
		lastDir = dirNameOfDir.slice(-4)
		if fileName is fileToFind && lastDir is '/env'
			return callback file, 0, null
	finder.on 'end', () ->
		return callback null, 1, null
	finder.on 'error', (err) ->
		return callback null, 0, err

findFiles parentDir, fileToFind, (file, status, err) ->
	if err
		console.log err
	else if status
		console.log filePaths
	else
		filePaths.push file


