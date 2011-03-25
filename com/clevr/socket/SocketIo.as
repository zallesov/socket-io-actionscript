/**
 * Socket.IO Actionscript client
 * 
 * @author Matt Kane
 * @license The MIT license.
 * @copyright Copyright (c) 2010 CLEVR Ltd
 */

package com.clevr.socket
{	
	import com.adobe.serialization.json.JSON;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLVariables;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import mx.utils.URLUtil;
	
	[Event(name="IoDataEventData", type="com.clevr.socket.SocketIOEvent")]
	public class SocketIo extends EventDispatcher {
		public var connected:Boolean = false;
		public var connecting:Boolean = false;
		public var host:String;
		public var options:Object;
		public var socket:WebSocket;
		public var sessionid:String;
		private var frame:String = '~m~';
		private var connectTimeout:*;	
		private var doReconnect:Boolean = true;
		private var reconnectTimeout:*;
		private var _queue:Array;
		/**
		 * @param host - host or url
		 * @param options (optional)
		 * port: connection port. default 80
		 * cookies:Object values to insert into http Cookie header.
		 * secure:Boolean true for using secure socket. default false
		 * headers:Striing Aditional headers devided with "\r\n"
		 * timeout:Number time in milliseconds to reconnect if no messeges were recieved during it. default 15000
		 */		
		public function SocketIo(host:String, options:Object=null) {
			super();
			this.options = {
				secure: false,
				port:  80,
				resource: 'socket.io',
				timeout: 15000
			}
			this.host = host;
			_queue = new Array();
			for(var p:String in options){
				this.options[p] = options[p];
			}
		}
		
		public function connect():void {
			if(connecting || connected) {
				return;
			}
			resetConnectTimeOut()
			if(reconnectTimeout) clearTimeout(reconnectTimeout);
			connecting = true;
			
			var cookiesStr:String = options["cookies"] ? URLUtil.objectToString(options["cookies"], "; ", true): "";
			var headersStr:String = options["headers"] ? options["headers"] : "";
			socket = new WebSocket(url, "",null,0, cookiesStr, headersStr);	
			trace("# SocketIO connecting to "+url)
			socket.addEventListener("message", onData);
			
			socket.addEventListener("close", onDisconnect);
			
			socket.addEventListener("error", onError);
			
			socket.connect();
		}
		
		public function disconnect():void {
			clearTimeout(reconnectTimeout);
			doReconnect = false;
			if(socket) socket.close();
			onDisconnect();
		}
		
		public function send(message:*):void {
			var encodedMessage:String = encode(message);
			trace("# SocketIO sending message: "+encodedMessage);
			write(encodedMessage);
		}
		
		protected function stringify(message:*):*{
			if (message is String){
				return String(message);
			} else {
				return '~j~' + JSON.encode(message);
			}
		};
		
		protected function encode(messages:*):String{
			var ret:String = '', message:String;
			messages = messages is Array ? messages : [messages];
			for (var i:int = 0; i < messages.length; i++){
				message = messages[i] == null ? '' : stringify(messages[i]);
				ret += frame + message.length + frame + message;
			}
			return ret;
		}
		
		protected function onData(event:Event):void {
			resetConnectTimeOut();
			var bunch:Array = socket.readSocketData();
			for (var i:int = 0; i < bunch.length; i++) {
				var msgs = decode(bunch[i]);
			}
		}
		
		protected function decode(data:String):void {
			var messages:Array = [], number, n;
			do {
				if (data.substr(0, 3) !== frame) return;
				data = data.substr(3);
				number = '', n = '';
				for (var i:int = 0, l:int = data.length; i < l; i++){
					n = Number(data.substr(i, 1));
					if (data.substr(i, 1) == n){
						number += n;
					} else {	
						data = data.substr(number.length + frame.length);
						number = Number(number);
						break;
					} 
				}
				onMessage(data.substr(0, number));
				data = data.substr(number);
			} while(data !== '');
		}
		
		protected function onMessage(message:String):void{
			if (!this.sessionid){
				sessionid = message;
				onConnect();
			} else if (message.substr(0, 3) == '~h~'){
				onHeartbeat(message);
			} else if (message.substr(0, 3) == '~j~'){
				var obj:* = JSON.decode(message.substr(3));
				trace("# SocketIO recieve message: "+message);
				dispatchEvent(new SocketIOEvent(SocketIOEvent.MESSAGE, obj));
			} else {
				trace("# SocketIO recieve message: "+message);
				dispatchEvent(new SocketIOEvent(SocketIOEvent.MESSAGE, message));
			}
		}
		
		protected function onHeartbeat(heartbeat:String):void{
			send(heartbeat);
		}
		
		protected function write(message:String):void {
			if(!connected || !socket) {
				enQueue(message);
			} else {
				socket.send(message);
			}
		}
		
		protected function enQueue(message:Object):void {
			if(!_queue) {
				_queue = new Array();
			}
			_queue.push(message);
		}
		
		protected function runQueue():void {
			if(_queue.length>0 && connected && socket) {
				while(_queue.length){
					write(_queue.shift());
				}
				_queue = new Array();
			}
		}

		protected function get url():String{
				return (options.secure ? 'wss' : 'ws') 
				+ '://' + host 
				+ ':' + options.port
				+ '/' + options.resource
				+ '/flashsocket'
				+ (sessionid ? ('/' + sessionid) : '');
		}
		
		protected function onError(message:String):void {
			trace("# SocketIO Error: " + message);
			dispatchEvent(new SocketIOEvent(SocketIOEvent.ERROR, {message:message}));
			if(socket){
				socket.close();
			}
			onDisconnect();
		}
		
		protected function onConnect(e:Event = null):void	{
			connected = true;
			connecting = false;
			runQueue();
			trace("# SocketIO connected "+url)
			dispatchEvent(new SocketIOEvent(SocketIOEvent.CONNECTED));
		}
		
		protected function onDisconnect(e:Event = null):void {
			var wasConnected:Boolean = connected;
			connected = false;
			connecting = false;
			sessionid = null;
			_queue = [];
			
			if(socket){
				socket.removeEventListener("close", onDisconnect);
				socket.removeEventListener("message", onData);
				socket.removeEventListener("error", onError);
				socket.close();
				socket = null;
			}
			
			dispatchEvent(new SocketIOEvent(wasConnected&&doReconnect?SocketIOEvent.RECONNECTING:SocketIOEvent.DISCONNECTED));
			
			if(doReconnect){
				trace("# SocketIO reconnecting");
				reconnectTimeout = setTimeout(connect, Math.round(4000+1000*Math.random()));
			}else{
				trace("# SocketIO disconnected")
			}
		}
		
		protected function resetConnectTimeOut():void{
			if(connectTimeout) clearTimeout(connectTimeout);
			connectTimeout = setTimeout(onDisconnect, options["timeout"]);
		}
	}
}