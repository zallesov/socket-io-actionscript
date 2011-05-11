/**
 * Socket.IO Actionscript client
 * @author Alexander Zalesov
 */

package com.zall.socketio
{	
	import com.adobe.serialization.json.JSON;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLVariables;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import mx.utils.URLUtil;
	
	[Event(name="IoDataEventData", type="com.zall.socketio.SocketIOEvent")]
	public class SocketIo extends EventDispatcher {
		public var connected:Boolean = false;
		public var connecting:Boolean = false;
		public var host:String;
		public var options:Object;
		public var socket:ISocketStreamer;
		public var sessionid:String;
		private var frame:String = '~m~';
		private var doReconnect:Boolean = true;
		private var connectTimeout:*;	
		private var reconnectTimeout:*;
		private var keepAliveTimeout:*;	
		private var _queue:Array;
		
		private var attempt:Number = 0;
		/**
		 * @param host - host or url
		 * @param options (optional)
		 * port: connection port. default 80
		 * cookies:Object values to insert into http Cookie header.
		 * secure:Boolean true for using secure socket. default false
		 * headers:Striing Aditional headers devided with "\r\n"
		 * keepalive_timeout:Number time in milliseconds to reconnect if no messeges were recieved during it. default 15000
		 * connect_timeout:Number time in milliseconds to fail the connection
		 */		
		public function SocketIo(host:String, options:Object=null) {
			super();
			this.options = {
				secure: false,
				port:  80,
				resource: 'socket.io',
				keepalive_timeout: 15000,
				connect_timeout:5000
			}
			this.host = host;
			_queue = new Array();
			for(var p:String in options){
				this.options[p] = options[p];
			}
		}
		/**
		 * Connects to socket server first with pure socket, then if fail with http tunel socket. 
		 * 
		 */		
		public function connect():void {
			if(connecting || connected) {
				return;
			}
			resetConnectTimeOut();
			if(keepAliveTimeout) clearTimeout(keepAliveTimeout); 
			if(reconnectTimeout) clearTimeout(reconnectTimeout);
			connecting = true;
			
			var cookiesStr:String = options["cookies"] ? URLUtil.objectToString(options["cookies"], "; ", true): "";
			var headersStr:String = options["headers"] ? options["headers"] : "";
			socket = TransportFactory.createSocket(attempt, host, options.port, options.resource, sessionid,cookiesStr, headersStr);
			trace("# SocketIO connecting to "+url)
			socket.addEventListener("message", onData);
			socket.addEventListener("open", onOpen);
			socket.addEventListener("close", onDisconnect);
			socket.addEventListener("error", onError);
			
			socket.connect();
		}
		
		public function get url():String{
			return socket.url;
		}
		/**
		 * Disconnect from socket server 
		 * 
		 */		
		public function disconnect():void {
			if(reconnectTimeout) clearTimeout(reconnectTimeout);
			if(keepAliveTimeout) clearTimeout(keepAliveTimeout);
			if(connectTimeout) clearTimeout(connectTimeout);
			reconnectTimeout = null;
			keepAliveTimeout = null;
			connectTimeout = null;
			doReconnect = false;
			onDisconnect();
		}
		
		/**
		 * Encodes and sends the message 
		 * @param message
		 * 
		 */		
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
			resetKeepAliveTimeOut();
			var bunch:Array = socket.read();
			for (var i:int = 0; i < bunch.length; i++) {
				decode(bunch[i]);
			}
		}
		
		protected function onOpen(event:Event):void{
			clearTimeout(connectTimeout);
			connectTimeout = null;
			resetKeepAliveTimeOut();
		}
		
		protected function decode(data:String):void {
			var messages:Array = [], number, n;
			var orig:String = data;
			do {
				if (data.substr(0, frame.length) !== frame) return;
				data = data.substr(frame.length);
				var numberStr:String = '', nChar:String = '', number:Number;
				for (var i:int = 0, l:int = data.length; i < l; i++){
					nChar = data.substr(i, 1);
					if (data.substr(i, frame.length) != frame){
						numberStr += nChar;
					} else {	
						data = data.substr(numberStr.length + frame.length);
						number = Number(numberStr);
						break;
					} 
				}
				onMessage(data.substr(0, Number(number)));
				data = data.substr(number);
			} while(data !== '');
		}
		
		protected function onMessage(message:String):void{
			if (!this.sessionid){
				sessionid = message;
				socket.setSession(sessionid);
				onConnect();
			} else if (message.substr(0, 3) == '~h~'){
				onHeartbeat(message);
			} else if (message.substr(0, 3) == '~j~'){
				try{
					var obj:* = JSON.decode(message.substr(3));
					trace("# SocketIO recieve message: "+message);
					dispatchEvent(new SocketIOEvent(SocketIOEvent.MESSAGE, obj));
				}catch(e:Error){
					trace(message);
				}
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

		protected function onError(message:String):void {
			trace("# SocketIO Error: " + message);
			dispatchEvent(new SocketIOEvent(SocketIOEvent.ERROR, {message:message}));

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
			
			clearTimeout(connectTimeout);
			
			if(socket){
				socket.removeEventListener("close", onDisconnect);
				socket.removeEventListener("message", onData);
				socket.removeEventListener("error", onError);
				socket.removeEventListener("open", onOpen);
				socket.close();
				socket = null;
			}
			
			if(!wasConnected){
				attempt++;
				if(attempt%TransportFactory.transportNum==0){
					trace("# SocketIO connect failed");
					dispatchEvent(new SocketIOEvent(SocketIOEvent.CONNECT_FAILED));
				}else{ 
					trace("# SocketIO using another transport");
					dispatchEvent(new SocketIOEvent(SocketIOEvent.ATTEMPT));
				}
			}
			if(doReconnect){
				trace("# SocketIO reconnecting");
				dispatchEvent(new SocketIOEvent(SocketIOEvent.RECONNECTING));
				reconnectTimeout = setTimeout(connect, Math.round(4000+1000*Math.random()));
			}else{
				trace("# SocketIO disconnected")
				dispatchEvent(new SocketIOEvent(SocketIOEvent.DISCONNECTED));
			}
			
		}
		
		protected function resetKeepAliveTimeOut():void{
			if(keepAliveTimeout) clearTimeout(keepAliveTimeout);
			keepAliveTimeout = setTimeout(onDisconnect, options["keepalive_timeout"]);
		}
		
		protected function resetConnectTimeOut():void{
			if(connectTimeout) clearTimeout(connectTimeout);
			connectTimeout = setTimeout(onDisconnect, options["connect_timeout"]);
		}
	}
}