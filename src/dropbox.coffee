fs = require 'fs'
{spawn} = require 'child_process'
S = require 'string'
qs = require 'querystring'

DROPBOX_UPLOADER_CONFIG = process.env.HOME + '/.dropbox_uploader'

auth_proc = null
auth_proc_dead = false

exports.authorize = ( callbackURL, cb ) ->
	appKey = process.env.DROPBOX_APP_KEY
	appSecret = process.env.DROPBOX_APP_SECRET
	if not appKey? or not appSecret?
		cb( 'You have to set DROPBOX_APP_KEY and DROPBOX_APP_SECRET environment variables from resin dashboard.' )
		return
	else
		console.log( 'Dropbox: Using app key "' + appKey + '" and app secret + "' + appSecret + '".' )

	try 
		fs.unlinkSync( DROPBOX_UPLOADER_CONFIG );
	catch e
		if e.code isnt 'ENOENT'
			cb( 'Error while removing dropbox uploader config: ' + e  )
			return

	buffer = ''

	auth_proc = spawn( './dropbox_uploader.sh', [] )
	auth_proc.stdout.on( 'data', ( data ) ->
		process.stdout.write( data )
		if auth_proc_dead
			cb( 'Dropbox uploader process terminated.' )
			return
		buffer += data
		urlPattern = ///-->\s+(https.*)\s///i
		authURLMatch = buffer.match urlPattern

		if S( buffer ).endsWith( ' # App key: ' )
			auth_proc.stdin.write( appKey + '\n' )
			buffer = ''
		else if S( buffer ).endsWith( ' # App secret: ' )
			auth_proc.stdin.write( appSecret + '\n' )
			buffer = ''
		else if S( buffer ).endsWith( ' [a/f]: ' )
			auth_proc.stdin.write( 'a\n' )
			buffer = ''
		else if S( buffer ).endsWith( ' Looks ok? [y/n]: ' )
			auth_proc.stdin.write( 'y\n' )
			buffer = ''
		else if authURLMatch?
			authURL = authURLMatch[ 1 ];
			authURL += '&oauth_callback=' + qs.escape( callbackURL )
			cb( null, authURL )
			buffer = ''
	)
	auth_proc.on( 'exit', ->
		auth_proc_dead = true
	)
	auth_proc.on( 'close', ->
		auth_proc_dead = true
	)
	auth_proc.on( 'error', (e) ->
		console.log( 'Error during calling dropbox uploader: ' + e )
	)

exports.authorized = ( cb ) ->
	if auth_proc_dead
		cb( 'Dropbox uploader process terminated during waiting for approval' )
	else
		auth_proc.stdin.write( '\n' )

exports.upload = ( localPath, remotePath, cb ) ->
	proc = spawn( './dropbox_uploader.sh', [ 'upload', localPath, remotePath ] )
	proc.on( 'close', (code) ->
		if code isnt 0
			cb( 'Dropbox upload process exited with code ' + code )
		else
			cb()
	)
