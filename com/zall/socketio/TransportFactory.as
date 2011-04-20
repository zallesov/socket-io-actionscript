/**
 * Socket.IO Actionscript client
 * 
 * @author Alexander Zalesov
 */
package com.zall.socketio
{
	public class TransportFactory
	{
		public static function createSocket(attempt:Number, host:String, port:int, resource:String, sessionId:String, coockies:String, headers:String):ISocketStreamer{
			var url:String;
			var currentTransport:Number = attempt%transportNum;
			if(currentTransport>0){
				url = "http" 
					+ '://' + host 
					+ ':' + port
					+ '/' + resource
					+ '/httpsocket'
					+ (sessionId ? ('/' + sessionId) : '');
				return new HTTPSocket(url);
			}else{
				url = "ws" 
					+ '://' + host 
					+ ':' + port
					+ '/' + resource
					+ '/flashsocket'
					+ (sessionId ? ('/' + sessionId) : '');
				return new WebSocket(url, null, null, 0, coockies, headers);
			}
		} 
		
		public static function get transportNum():int{
			return 2;
		}
	}
}