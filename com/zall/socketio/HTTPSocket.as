/**
 * Socket.IO Actionscript client
 * 
 * @author Alexander Zalesov
 */
package com.zall.socketio
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLStream;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;

	/**
	 * One of socket transports for socketIO. Can be also used single. 
	 * @author Zallesov
	 * 
	 */	
	[Event(name="error", type="flash.events.Event")]
	[Event(name="close", type="flash.events.Event")]
	[Event(name="open", type="flash.events.Event")]
	[Event(name="message", type="flash.events.Event")]
	public class HTTPSocket extends EventDispatcher implements ISocketStreamer
	{
		private var streamIn:URLStream;
		private var _url:String
		private var dataQueue:Array = [];
		private var buffer:ByteArray = new ByteArray;
		private var buffer2:ByteArray = new ByteArray;
		private var sessionId:String = "";
		
		public var error:String;
		
		public function HTTPSocket(url:String)
		{
			this._url = url;
		}
		
		public function get url():String{
			return _url;
		}
		
		public function connect():void{
			if(streamIn){
				close();
			}
			
			streamIn = new URLStream();
			var request:* = new URLRequest(_url);
			request.method = "get";
			streamIn.load(request);
			
			streamIn.addEventListener(ProgressEvent.PROGRESS, onRead);
			streamIn.addEventListener(Event.OPEN, onConnect);
			streamIn.addEventListener(Event.COMPLETE, onClose);
			streamIn.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			streamIn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		}
		
		public function send(encData:String):int{
			var request:URLRequest = new URLRequest(_url);
			var vars:URLVariables = new URLVariables(null);
			vars.data = encData;
			vars.sessionId = sessionId;
			request.data = vars;
			request.method = "post";
			var loader:URLLoader = new URLLoader(request);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onSendError);
			
			return 100500;
		}
		
		public function close():void{
			if(!streamIn) return;
			try{
				streamIn.removeEventListener(ProgressEvent.PROGRESS, onRead);
				streamIn.removeEventListener(Event.OPEN, onConnect);
				streamIn.removeEventListener(Event.COMPLETE, onClose);
				streamIn.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				streamIn.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				streamIn.close();
				dispatchEvent(new Event("close"));
			}catch(e:Error){};
		}
		
		public function read():Array{
			var q:Array = dataQueue;
			if (dataQueue.length > 0) {
				dataQueue = [];
			}
			return q;
		}
		
		private function onSendError(e:Event):void{
			onError("Error on sending data to "+_url);
		}
		
		protected function onConnect(e:Event):void{
			dispatchEvent(new Event("open"))
		}
		
		protected function onRead(e:Event):void{
			if (streamIn.bytesAvailable > 0){
				var k: Number = buffer.length;
				streamIn.readBytes(buffer,buffer.length,streamIn.bytesAvailable);
				var packDelimeter:int = 0xa; // /r/n
				buffer.position = k;
				var pack:String;
				while (buffer.position<buffer.length)
				{
					var byte:int = buffer.readByte();
					if(byte==packDelimeter){
						var length:int = buffer.position;
						buffer.position = 0;
						pack = buffer.readUTFBytes(length);
						
						buffer.readBytes(buffer2,0,buffer.length-buffer.position);
						var tmp:* = buffer;
						buffer.clear();
						buffer = buffer2;
						buffer2 = tmp;
						if(pack.indexOf("<html><body>")==-1){// workaround for IE;
							dataQueue.push(pack);
						}
					}
				}
				if(dataQueue.length>0){
					dispatchEvent(new Event("message"));
				}
			}
		}
		
		protected function onClose(e:Event):void{
			dispatchEvent(new Event("close"));
		}
		
		protected function ioErrorHandler(e:Event):void{
			onError("ioError");
		}
		
		protected function securityErrorHandler(e:Event):void{
			onError("Security Error");
		}
		
		private function onError(message:String):void {
			trace("# HTTPSocket ERROR: "+message);
			dispatchEvent(new Event("error"));
			close();
		}
		
		public function setSession(sessionId:String):void{
			this.sessionId = sessionId;
		}
	}
}