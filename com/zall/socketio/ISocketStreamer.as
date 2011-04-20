/**
 * Socket.IO Actionscript client
 * 
 * @author Alexander Zalesov
 */
package com.zall.socketio
{
	import flash.events.IEventDispatcher;

	public interface ISocketStreamer extends IEventDispatcher
	{
		function connect():void;
		
		function send(encData:String):int;
		
		function close():void;
		
		function read():Array;
		
		function setSession(sessionId:String):void;
		
		function get url():String;
		
	}
}