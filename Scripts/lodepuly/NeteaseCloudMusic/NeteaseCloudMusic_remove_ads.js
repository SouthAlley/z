/*
脚本引用https://raw.githubusercontent.com/Keywos/rule/main/script/wy/js/wyres.js
*/
// @timestamp thenkey 2024-03-14 16:01:17
(()=>{var Y=typeof globalThis<"u"?globalThis:typeof window<"u"?window:typeof global<"u"?global:typeof self<"u"?self:{};function Re(l){return l&&l.__esModule&&Object.prototype.hasOwnProperty.call(l,"default")?l.default:l}function xe(l){if(l.__esModule)return l;var R=l.default;if(typeof R=="function"){var A=function C(){return this instanceof C?Reflect.construct(R,arguments,this.constructor):R.apply(this,arguments)};A.prototype=R.prototype}else A={};return Object.defineProperty(A,"__esModule",{value:!0}),Object.keys(l).forEach(function(C){var h=Object.getOwnPropertyDescriptor(l,C);Object.defineProperty(A,C,h.get?h:{enumerable:!0,get:function(){return l[C]}})}),A}var Oe={exports:{}},J={exports:{}},De=xe(Object.freeze(Object.defineProperty({__proto__:null,default:{}},Symbol.toStringTag,{value:"Module"}))),W;function L(){return W||(W=1,J.exports=(l=l||function(R,A){var C;if(typeof window<"u"&&window.crypto&&(C=window.crypto),typeof self<"u"&&self.crypto&&(C=self.crypto),typeof globalThis<"u"&&globalThis.crypto&&(C=globalThis.crypto),!C&&typeof window<"u"&&window.msCrypto&&(C=window.msCrypto),!C&&Y!==void 0&&Y.crypto&&(C=Y.crypto),!C)try{C=De}catch{}var h=function(){if(C){if(typeof C.getRandomValues=="function")try{return C.getRandomValues(new Uint32Array(1))[0]}catch{}if(typeof C.randomBytes=="function")try{return C.randomBytes(4).readInt32LE()}catch{}}throw new Error("Native crypto module could not be used to get secure random number.")},b=Object.create||function(){function e(){}return function(i){var s;return e.prototype=i,s=new e,e.prototype=null,s}}(),D={},o=D.lib={},x=o.Base=function(){return{extend:function(e){var i=b(this);return e&&i.mixIn(e),i.hasOwnProperty("init")&&this.init!==i.init||(i.init=function(){i.$super.init.apply(this,arguments)}),i.init.prototype=i,i.$super=this,i},create:function(){var e=this.extend();return e.init.apply(e,arguments),e},init:function(){},mixIn:function(e){for(var i in e)e.hasOwnProperty(i)&&(this[i]=e[i]);e.hasOwnProperty("toString")&&(this.toString=e.toString)},clone:function(){return this.init.prototype.extend(this)}}}(),E=o.WordArray=x.extend({init:function(e,i){e=this.words=e||[],this.sigBytes=i!=A?i:4*e.length},toString:function(e){return(e||m).stringify(this)},concat:function(e){var i=this.words,s=e.words,g=this.sigBytes,t=e.sigBytes;if(this.clamp(),g%4)for(var n=0;n<t;n++){var v=s[n>>>2]>>>24-n%4*8&255;i[g+n>>>2]|=v<<24-(g+n)%4*8}else for(var a=0;a<t;a+=4)i[g+a>>>2]=s[a>>>2];return this.sigBytes+=t,this},clamp:function(){var e=this.words,i=this.sigBytes;e[i>>>2]&=4294967295<<32-i%4*8,e.length=R.ceil(i/4)},clone:function(){var e=x.clone.call(this);return e.words=this.words.slice(0),e},random:function(e){for(var i=[],s=0;s<e;s+=4)i.push(h());return new E.init(i,e)}}),r=D.enc={},m=r.Hex={stringify:function(e){for(var i=e.words,s=e.sigBytes,g=[],t=0;t<s;t++){var n=i[t>>>2]>>>24-t%4*8&255;g.push((n>>>4).toString(16)),g.push((15&n).toString(16))}return g.join("")},parse:function(e){for(var i=e.length,s=[],g=0;g<i;g+=2)s[g>>>3]|=parseInt(e.substr(g,2),16)<<24-g%8*4;return new E.init(s,i/2)}},c=r.Latin1={stringify:function(e){for(var i=e.words,s=e.sigBytes,g=[],t=0;t<s;t++){var n=i[t>>>2]>>>24-t%4*8&255;g.push(String.fromCharCode(n))}return g.join("")},parse:function(e){for(var i=e.length,s=[],g=0;g<i;g++)s[g>>>2]|=(255&e.charCodeAt(g))<<24-g%4*8;return new E.init(s,i)}},k=r.Utf8={stringify:function(e){try{return decodeURIComponent(escape(c.stringify(e)))}catch{throw new Error("Malformed UTF-8 data")}},parse:function(e){return c.parse(unescape(encodeURIComponent(e)))}},M=o.BufferedBlockAlgorithm=x.extend({reset:function(){this._data=new E.init,this._nDataBytes=0},_append:function(e){typeof e=="string"&&(e=k.parse(e)),this._data.concat(e),this._nDataBytes+=e.sigBytes},_process:function(e){var i,s=this._data,g=s.words,t=s.sigBytes,n=this.blockSize,v=t/(4*n),a=(v=e?R.ceil(v):R.max((0|v)-this._minBufferSize,0))*n,y=R.min(4*a,t);if(a){for(var O=0;O<a;O+=n)this._doProcessBlock(g,O);i=g.splice(0,a),s.sigBytes-=y}return new E.init(i,y)},clone:function(){var e=x.clone.call(this);return e._data=this._data.clone(),e},_minBufferSize:0});o.Hasher=M.extend({cfg:x.extend(),init:function(e){this.cfg=this.cfg.extend(e),this.reset()},reset:function(){M.reset.call(this),this._doReset()},update:function(e){return this._append(e),this._process(),this},finalize:function(e){return e&&this._append(e),this._doFinalize()},blockSize:16,_createHelper:function(e){return function(i,s){return new e.init(s).finalize(i)}},_createHmacHelper:function(e){return function(i,s){return new B.HMAC.init(e,s).finalize(i)}}});var B=D.algo={};return D}(Math),l)),J.exports;var l}var X,q={exports:{}};function Be(){return X||(X=1,q.exports=(l=L(),function(){if(typeof ArrayBuffer=="function"){var R=l.lib.WordArray,A=R.init,C=R.init=function(h){if(h instanceof ArrayBuffer&&(h=new Uint8Array(h)),(h instanceof Int8Array||typeof Uint8ClampedArray<"u"&&h instanceof Uint8ClampedArray||h instanceof Int16Array||h instanceof Uint16Array||h instanceof Int32Array||h instanceof Uint32Array||h instanceof Float32Array||h instanceof Float64Array)&&(h=new Uint8Array(h.buffer,h.byteOffset,h.byteLength)),h instanceof Uint8Array){for(var b=h.byteLength,D=[],o=0;o<b;o++)D[o>>>2]|=h[o]<<24-o%4*8;A.call(this,D,b)}else A.apply(this,arguments)};C.prototype=R}}(),l.lib.WordArray)),q.exports;var l}var Q,Se={exports:{}},Z={exports:{}},ee={exports:{}},te={exports:{}};function we(){return Q||(Q=1,te.exports=(o=L(),R=(l=o).lib,A=R.WordArray,C=R.Hasher,h=l.algo,b=[],D=h.SHA1=C.extend({_doReset:function(){this._hash=new A.init([1732584193,4023233417,2562383102,271733878,3285377520])},_doProcessBlock:function(x,E){for(var r=this._hash.words,m=r[0],c=r[1],k=r[2],M=r[3],B=r[4],e=0;e<80;e++){if(e<16)b[e]=0|x[E+e];else{var i=b[e-3]^b[e-8]^b[e-14]^b[e-16];b[e]=i<<1|i>>>31}var s=(m<<5|m>>>27)+B+b[e];s+=e<20?1518500249+(c&k|~c&M):e<40?1859775393+(c^k^M):e<60?(c&k|c&M|k&M)-1894007588:(c^k^M)-899497514,B=M,M=k,k=c<<30|c>>>2,c=m,m=s}r[0]=r[0]+m|0,r[1]=r[1]+c|0,r[2]=r[2]+k|0,r[3]=r[3]+M|0,r[4]=r[4]+B|0},_doFinalize:function(){var x=this._data,E=x.words,r=8*this._nDataBytes,m=8*x.sigBytes;return E[m>>>5]|=128<<24-m%32,E[14+(m+64>>>9<<4)]=Math.floor(r/4294967296),E[15+(m+64>>>9<<4)]=r,x.sigBytes=4*E.length,this._process(),this._hash},clone:function(){var x=C.clone.call(this);return x._hash=this._hash.clone(),x}}),l.SHA1=C._createHelper(D),l.HmacSHA1=C._createHmacHelper(D),o.SHA1)),te.exports;var l,R,A,C,h,b,D,o}var re,ne,ie,oe,ae={exports:{}};function he(){return ne||(ne=1,ee.exports=function(h){return function(){var b=h,D=b.lib,o=D.Base,x=D.WordArray,E=b.algo,r=E.MD5,m=E.EvpKDF=o.extend({cfg:o.extend({keySize:4,hasher:r,iterations:1}),init:function(c){this.cfg=this.cfg.extend(c)},compute:function(c,k){for(var M,B=this.cfg,e=B.hasher.create(),i=x.create(),s=i.words,g=B.keySize,t=B.iterations;s.length<g;){M&&e.update(M),M=e.update(c).finalize(k),e.reset();for(var n=1;n<t;n++)M=e.finalize(M),e.reset();i.concat(M)}return i.sigBytes=4*g,i}});b.EvpKDF=function(c,k,M){return m.create(M).compute(c,k)}}(),h.EvpKDF}(L(),we(),(re||(re=1,ae.exports=(l=L(),A=(R=l).lib.Base,C=R.enc.Utf8,void(R.algo.HMAC=A.extend({init:function(h,b){h=this._hasher=new h.init,typeof b=="string"&&(b=C.parse(b));var D=h.blockSize,o=4*D;b.sigBytes>o&&(b=h.finalize(b)),b.clamp();for(var x=this._oKey=b.clone(),E=this._iKey=b.clone(),r=x.words,m=E.words,c=0;c<D;c++)r[c]^=1549556828,m[c]^=909522486;x.sigBytes=E.sigBytes=o,this.reset()},reset:function(){var h=this._hasher;h.reset(),h.update(this._iKey)},update:function(h){return this._hasher.update(h),this},finalize:function(h){var b=this._hasher,D=b.finalize(h);return b.reset(),b.finalize(this._oKey.clone().concat(D))}})))),ae.exports))),ee.exports;var l,R,A,C}function se(){return ie||(ie=1,Z.exports=(l=L(),he(),void(l.lib.Cipher||function(R){var A=l,C=A.lib,h=C.Base,b=C.WordArray,D=C.BufferedBlockAlgorithm,o=A.enc;o.Utf8;var x=o.Base64,E=A.algo.EvpKDF,r=C.Cipher=D.extend({cfg:h.extend(),createEncryptor:function(t,n){return this.create(this._ENC_XFORM_MODE,t,n)},createDecryptor:function(t,n){return this.create(this._DEC_XFORM_MODE,t,n)},init:function(t,n,v){this.cfg=this.cfg.extend(v),this._xformMode=t,this._key=n,this.reset()},reset:function(){D.reset.call(this),this._doReset()},process:function(t){return this._append(t),this._process()},finalize:function(t){return t&&this._append(t),this._doFinalize()},keySize:4,ivSize:4,_ENC_XFORM_MODE:1,_DEC_XFORM_MODE:2,_createHelper:function(){function t(n){return typeof n=="string"?g:i}return function(n){return{encrypt:function(v,a,y){return t(a).encrypt(n,v,a,y)},decrypt:function(v,a,y){return t(a).decrypt(n,v,a,y)}}}}()});C.StreamCipher=r.extend({_doFinalize:function(){return this._process(!0)},blockSize:1});var m=A.mode={},c=C.BlockCipherMode=h.extend({createEncryptor:function(t,n){return this.Encryptor.create(t,n)},createDecryptor:function(t,n){return this.Decryptor.create(t,n)},init:function(t,n){this._cipher=t,this._iv=n}}),k=m.CBC=function(){var t=c.extend();function n(v,a,y){var O,S=this._iv;S?(O=S,this._iv=R):O=this._prevBlock;for(var w=0;w<y;w++)v[a+w]^=O[w]}return t.Encryptor=t.extend({processBlock:function(v,a){var y=this._cipher,O=y.blockSize;n.call(this,v,a,O),y.encryptBlock(v,a),this._prevBlock=v.slice(a,a+O)}}),t.Decryptor=t.extend({processBlock:function(v,a){var y=this._cipher,O=y.blockSize,S=v.slice(a,a+O);y.decryptBlock(v,a),n.call(this,v,a,O),this._prevBlock=S}}),t}(),M=(A.pad={}).Pkcs7={pad:function(t,n){for(var v=4*n,a=v-t.sigBytes%v,y=a<<24|a<<16|a<<8|a,O=[],S=0;S<a;S+=4)O.push(y);var w=b.create(O,a);t.concat(w)},unpad:function(t){var n=255&t.words[t.sigBytes-1>>>2];t.sigBytes-=n}};C.BlockCipher=r.extend({cfg:r.cfg.extend({mode:k,padding:M}),reset:function(){var t;r.reset.call(this);var n=this.cfg,v=n.iv,a=n.mode;this._xformMode==this._ENC_XFORM_MODE?t=a.createEncryptor:(t=a.createDecryptor,this._minBufferSize=1),this._mode&&this._mode.__creator==t?this._mode.init(this,v&&v.words):(this._mode=t.call(a,this,v&&v.words),this._mode.__creator=t)},_doProcessBlock:function(t,n){this._mode.processBlock(t,n)},_doFinalize:function(){var t,n=this.cfg.padding;return this._xformMode==this._ENC_XFORM_MODE?(n.pad(this._data,this.blockSize),t=this._process(!0)):(t=this._process(!0),n.unpad(t)),t},blockSize:4});var B=C.CipherParams=h.extend({init:function(t){this.mixIn(t)},toString:function(t){return(t||this.formatter).stringify(this)}}),e=(A.format={}).OpenSSL={stringify:function(t){var n=t.ciphertext,v=t.salt;return(v?b.create([1398893684,1701076831]).concat(v).concat(n):n).toString(x)},parse:function(t){var n,v=x.parse(t),a=v.words;return a[0]==1398893684&&a[1]==1701076831&&(n=b.create(a.slice(2,4)),a.splice(0,4),v.sigBytes-=16),B.create({ciphertext:v,salt:n})}},i=C.SerializableCipher=h.extend({cfg:h.extend({format:e}),encrypt:function(t,n,v,a){a=this.cfg.extend(a);var y=t.createEncryptor(v,a),O=y.finalize(n),S=y.cfg;return B.create({ciphertext:O,key:v,iv:S.iv,algorithm:t,mode:S.mode,padding:S.padding,blockSize:t.blockSize,formatter:a.format})},decrypt:function(t,n,v,a){return a=this.cfg.extend(a),n=this._parse(n,a.format),t.createDecryptor(v,a).finalize(n.ciphertext)},_parse:function(t,n){return typeof t=="string"?n.parse(t,this):t}}),s=(A.kdf={}).OpenSSL={execute:function(t,n,v,a,y){if(a||(a=b.random(8)),y)O=E.create({keySize:n+v,hasher:y}).compute(t,a);else var O=E.create({keySize:n+v}).compute(t,a);var S=b.create(O.words.slice(n),4*v);return O.sigBytes=4*n,B.create({key:O,iv:S,salt:a})}},g=C.PasswordBasedCipher=i.extend({cfg:i.cfg.extend({kdf:s}),encrypt:function(t,n,v,a){var y=(a=this.cfg.extend(a)).kdf.execute(v,t.keySize,t.ivSize,a.salt,a.hasher);a.iv=y.iv;var O=i.encrypt.call(this,t,n,y.key,a);return O.mixIn(y),O},decrypt:function(t,n,v,a){a=this.cfg.extend(a),n=this._parse(n,a.format);var y=a.kdf.execute(v,t.keySize,t.ivSize,n.salt,a.hasher);return a.iv=y.iv,i.decrypt.call(this,t,n,y.key,a)}})}()))),Z.exports;var l}var ce,le={exports:{}},fe={exports:{}};function Pe(){return ce||(ce=1,fe.exports=(l=L(),function(){var R=l,A=R.lib.WordArray;function C(h,b,D){for(var o=[],x=0,E=0;E<b;E++)if(E%4){var r=D[h.charCodeAt(E-1)]<<E%4*2|D[h.charCodeAt(E)]>>>6-E%4*2;o[x>>>2]|=r<<24-x%4*8,x++}return A.create(o,x)}R.enc.Base64={stringify:function(h){var b=h.words,D=h.sigBytes,o=this._map;h.clamp();for(var x=[],E=0;E<D;E+=3)for(var r=(b[E>>>2]>>>24-E%4*8&255)<<16|(b[E+1>>>2]>>>24-(E+1)%4*8&255)<<8|b[E+2>>>2]>>>24-(E+2)%4*8&255,m=0;m<4&&E+.75*m<D;m++)x.push(o.charAt(r>>>6*(3-m)&63));var c=o.charAt(64);if(c)for(;x.length%4;)x.push(c);return x.join("")},parse:function(h){var b=h.length,D=this._map,o=this._reverseMap;if(!o){o=this._reverseMap=[];for(var x=0;x<D.length;x++)o[D.charCodeAt(x)]=x}var E=D.charAt(64);if(E){var r=h.indexOf(E);r!==-1&&(b=r)}return C(h,b,o)},_map:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="}}(),l.enc.Base64)),fe.exports;var l}var de,ue,$,K,pe={exports:{}};function Ne(){return de||(de=1,pe.exports=(l=L(),function(R){var A=l,C=A.lib,h=C.WordArray,b=C.Hasher,D=A.algo,o=[];(function(){for(var k=0;k<64;k++)o[k]=4294967296*R.abs(R.sin(k+1))|0})();var x=D.MD5=b.extend({_doReset:function(){this._hash=new h.init([1732584193,4023233417,2562383102,271733878])},_doProcessBlock:function(k,M){for(var B=0;B<16;B++){var e=M+B,i=k[e];k[e]=16711935&(i<<8|i>>>24)|4278255360&(i<<24|i>>>8)}var s=this._hash.words,g=k[M+0],t=k[M+1],n=k[M+2],v=k[M+3],a=k[M+4],y=k[M+5],O=k[M+6],S=k[M+7],w=k[M+8],P=k[M+9],N=k[M+10],U=k[M+11],z=k[M+12],G=k[M+13],I=k[M+14],H=k[M+15],f=s[0],_=s[1],d=s[2],u=s[3];f=E(f,_,d,u,g,7,o[0]),u=E(u,f,_,d,t,12,o[1]),d=E(d,u,f,_,n,17,o[2]),_=E(_,d,u,f,v,22,o[3]),f=E(f,_,d,u,a,7,o[4]),u=E(u,f,_,d,y,12,o[5]),d=E(d,u,f,_,O,17,o[6]),_=E(_,d,u,f,S,22,o[7]),f=E(f,_,d,u,w,7,o[8]),u=E(u,f,_,d,P,12,o[9]),d=E(d,u,f,_,N,17,o[10]),_=E(_,d,u,f,U,22,o[11]),f=E(f,_,d,u,z,7,o[12]),u=E(u,f,_,d,G,12,o[13]),d=E(d,u,f,_,I,17,o[14]),f=r(f,_=E(_,d,u,f,H,22,o[15]),d,u,t,5,o[16]),u=r(u,f,_,d,O,9,o[17]),d=r(d,u,f,_,U,14,o[18]),_=r(_,d,u,f,g,20,o[19]),f=r(f,_,d,u,y,5,o[20]),u=r(u,f,_,d,N,9,o[21]),d=r(d,u,f,_,H,14,o[22]),_=r(_,d,u,f,a,20,o[23]),f=r(f,_,d,u,P,5,o[24]),u=r(u,f,_,d,I,9,o[25]),d=r(d,u,f,_,v,14,o[26]),_=r(_,d,u,f,w,20,o[27]),f=r(f,_,d,u,G,5,o[28]),u=r(u,f,_,d,n,9,o[29]),d=r(d,u,f,_,S,14,o[30]),f=m(f,_=r(_,d,u,f,z,20,o[31]),d,u,y,4,o[32]),u=m(u,f,_,d,w,11,o[33]),d=m(d,u,f,_,U,16,o[34]),_=m(_,d,u,f,I,23,o[35]),f=m(f,_,d,u,t,4,o[36]),u=m(u,f,_,d,a,11,o[37]),d=m(d,u,f,_,S,16,o[38]),_=m(_,d,u,f,N,23,o[39]),f=m(f,_,d,u,G,4,o[40]),u=m(u,f,_,d,g,11,o[41]),d=m(d,u,f,_,v,16,o[42]),_=m(_,d,u,f,O,23,o[43]),f=m(f,_,d,u,P,4,o[44]),u=m(u,f,_,d,z,11,o[45]),d=m(d,u,f,_,H,16,o[46]),f=c(f,_=m(_,d,u,f,n,23,o[47]),d,u,g,6,o[48]),u=c(u,f,_,d,S,10,o[49]),d=c(d,u,f,_,I,15,o[50]),_=c(_,d,u,f,y,21,o[51]),f=c(f,_,d,u,z,6,o[52]),u=c(u,f,_,d,v,10,o[53]),d=c(d,u,f,_,N,15,o[54]),_=c(_,d,u,f,t,21,o[55]),f=c(f,_,d,u,w,6,o[56]),u=c(u,f,_,d,H,10,o[57]),d=c(d,u,f,_,O,15,o[58]),_=c(_,d,u,f,G,21,o[59]),f=c(f,_,d,u,a,6,o[60]),u=c(u,f,_,d,U,10,o[61]),d=c(d,u,f,_,n,15,o[62]),_=c(_,d,u,f,P,21,o[63]),s[0]=s[0]+f|0,s[1]=s[1]+_|0,s[2]=s[2]+d|0,s[3]=s[3]+u|0},_doFinalize:function(){var k=this._data,M=k.words,B=8*this._nDataBytes,e=8*k.sigBytes;M[e>>>5]|=128<<24-e%32;var i=R.floor(B/4294967296),s=B;M[15+(e+64>>>9<<4)]=16711935&(i<<8|i>>>24)|4278255360&(i<<24|i>>>8),M[14+(e+64>>>9<<4)]=16711935&(s<<8|s>>>24)|4278255360&(s<<24|s>>>8),k.sigBytes=4*(M.length+1),this._process();for(var g=this._hash,t=g.words,n=0;n<4;n++){var v=t[n];t[n]=16711935&(v<<8|v>>>24)|4278255360&(v<<24|v>>>8)}return g},clone:function(){var k=b.clone.call(this);return k._hash=this._hash.clone(),k}});function E(k,M,B,e,i,s,g){var t=k+(M&B|~M&e)+i+g;return(t<<s|t>>>32-s)+M}function r(k,M,B,e,i,s,g){var t=k+(M&e|B&~e)+i+g;return(t<<s|t>>>32-s)+M}function m(k,M,B,e,i,s,g){var t=k+(M^B^e)+i+g;return(t<<s|t>>>32-s)+M}function c(k,M,B,e,i,s,g){var t=k+(B^(M|~e))+i+g;return(t<<s|t>>>32-s)+M}A.MD5=b._createHelper(x),A.HmacMD5=b._createHmacHelper(x)}(Math),l.MD5)),pe.exports;var l}var T=Re(Oe.exports=function(l){return l}(L(),Be(),oe||(oe=1,Se.exports=(K=L(),se(),K.mode.ECB=(($=K.lib.BlockCipherMode.extend()).Encryptor=$.extend({processBlock:function(l,R){this._cipher.encryptBlock(l,R)}}),$.Decryptor=$.extend({processBlock:function(l,R){this._cipher.decryptBlock(l,R)}}),$),K.mode.ECB)),function(){return ue?le.exports:(ue=1,le.exports=(l=L(),Pe(),Ne(),he(),se(),function(){var R=l,A=R.lib.BlockCipher,C=R.algo,h=[],b=[],D=[],o=[],x=[],E=[],r=[],m=[],c=[],k=[];(function(){for(var e=[],i=0;i<256;i++)e[i]=i<128?i<<1:i<<1^283;var s=0,g=0;for(i=0;i<256;i++){var t=g^g<<1^g<<2^g<<3^g<<4;t=t>>>8^255&t^99,h[s]=t,b[t]=s;var n=e[s],v=e[n],a=e[v],y=257*e[t]^16843008*t;D[s]=y<<24|y>>>8,o[s]=y<<16|y>>>16,x[s]=y<<8|y>>>24,E[s]=y,y=16843009*a^65537*v^257*n^16843008*s,r[t]=y<<24|y>>>8,m[t]=y<<16|y>>>16,c[t]=y<<8|y>>>24,k[t]=y,s?(s=n^e[e[e[a^n]]],g^=e[e[g]]):s=g=1}})();var M=[0,1,2,4,8,16,32,64,128,27,54],B=C.AES=A.extend({_doReset:function(){if(!this._nRounds||this._keyPriorReset!==this._key){for(var e=this._keyPriorReset=this._key,i=e.words,s=e.sigBytes/4,g=4*((this._nRounds=s+6)+1),t=this._keySchedule=[],n=0;n<g;n++)n<s?t[n]=i[n]:(y=t[n-1],n%s?s>6&&n%s==4&&(y=h[y>>>24]<<24|h[y>>>16&255]<<16|h[y>>>8&255]<<8|h[255&y]):(y=h[(y=y<<8|y>>>24)>>>24]<<24|h[y>>>16&255]<<16|h[y>>>8&255]<<8|h[255&y],y^=M[n/s|0]<<24),t[n]=t[n-s]^y);for(var v=this._invKeySchedule=[],a=0;a<g;a++){if(n=g-a,a%4)var y=t[n];else y=t[n-4];v[a]=a<4||n<=4?y:r[h[y>>>24]]^m[h[y>>>16&255]]^c[h[y>>>8&255]]^k[h[255&y]]}}},encryptBlock:function(e,i){this._doCryptBlock(e,i,this._keySchedule,D,o,x,E,h)},decryptBlock:function(e,i){var s=e[i+1];e[i+1]=e[i+3],e[i+3]=s,this._doCryptBlock(e,i,this._invKeySchedule,r,m,c,k,b),s=e[i+1],e[i+1]=e[i+3],e[i+3]=s},_doCryptBlock:function(e,i,s,g,t,n,v,a){for(var y=this._nRounds,O=e[i]^s[0],S=e[i+1]^s[1],w=e[i+2]^s[2],P=e[i+3]^s[3],N=4,U=1;U<y;U++){var z=g[O>>>24]^t[S>>>16&255]^n[w>>>8&255]^v[255&P]^s[N++],G=g[S>>>24]^t[w>>>16&255]^n[P>>>8&255]^v[255&O]^s[N++],I=g[w>>>24]^t[P>>>16&255]^n[O>>>8&255]^v[255&S]^s[N++],H=g[P>>>24]^t[O>>>16&255]^n[S>>>8&255]^v[255&w]^s[N++];O=z,S=G,w=I,P=H}z=(a[O>>>24]<<24|a[S>>>16&255]<<16|a[w>>>8&255]<<8|a[255&P])^s[N++],G=(a[S>>>24]<<24|a[w>>>16&255]<<16|a[P>>>8&255]<<8|a[255&O])^s[N++],I=(a[w>>>24]<<24|a[P>>>16&255]<<16|a[O>>>8&255]<<8|a[255&S])^s[N++],H=(a[P>>>24]<<24|a[O>>>16&255]<<16|a[S>>>8&255]<<8|a[255&w])^s[N++],e[i]=z,e[i+1]=G,e[i+2]=I,e[i+3]=H},keySize:8});R.AES=A._createHelper(B)}(),l.AES));var l}()));var be={words:[1698181731,1801809512,946104675,1751477816],sigBytes:16};function _e(l){try{return l=T.AES.decrypt({ciphertext:T.lib.WordArray.create(l)},be,{mode:T.mode.ECB,padding:T.pad.Pkcs7}),JSON.parse(T.enc.Utf8.stringify(l))}catch(R){return console.log(R.message),null}}function Le(l){l=T.AES.encrypt(JSON.stringify(l),be,{mode:T.mode.ECB,padding:T.pad.Pkcs7}).ciphertext;let R=new Uint8Array(l.sigBytes);for(let A=0;A<l.sigBytes;A++)R[A]=l.words[A>>>2]>>>24-A%4*8&255;return R}var Ce=typeof $task<"u",Te=$request.url,p=$response.body,ye=$response.headers,me=ye["content-type"]||ye["Content-Type"]||"";!me.includes("application/json")&&!p&&(console.log("contentType\u4E0D\u5339\u914D"+me),$done({}));var ve={},Ee=Te.match(/(?:https?:\/\/[^\/]+)?\/(?:eapi|api)(\/.*)/)?.[1];Ce?p=_e($response.bodyBytes):p=_e(p);var Ae=()=>typeof $environment<"u"&&$environment["surge-version"]?"Surge":typeof $loon<"u"?"Loon":void 0,V=2e12,j=["PAGE_RECOMMEND_DAILY_RECOMMEND","PAGE_RECOMMEND_SPECIAL_CLOUD_VILLAGE_PLAYLIST","PAGE_RECOMMEND_SHORTCUT","HOMEPAGE_MUSIC_PARTNER","PAGE_RECOMMEND_RADAR","PAGE_RECOMMEND_RANK"];function ge(){let l=Ae();if(l==="Surge"){if(typeof $argument<"u"&&$argument!=="")try{let R={PRGG:"PAGE_RECOMMEND_GREETING",PRDRD:"PAGE_RECOMMEND_DAILY_RECOMMEND",PRSCVPT:"PAGE_RECOMMEND_SPECIAL_CLOUD_VILLAGE_PLAYLIST",PRST:"PAGE_RECOMMEND_SHORTCUT",HMPR:"HOMEPAGE_MUSIC_PARTNER",PRRR:"PAGE_RECOMMEND_RADAR",PRRK:"PAGE_RECOMMEND_RANK",PRMST:"PAGE_RECOMMEND_MY_SHEET",PRCN:"PAGE_RECOMMEND_COMBINATION"};F=JSON.parse($argument),j=Object.keys(F).filter(A=>F[A]!=0).map(A=>R[A])}catch{}}else l==="Loon"&&(j=[["\u9690\u85CF\u9996\u9875\u95EE\u5019\u8BED","PAGE_RECOMMEND_GREETING"],["\u9690\u85CF\u9996\u9875\u6BCF\u65E5\u63A8\u8350","PAGE_RECOMMEND_DAILY_RECOMMEND"],["\u9690\u85CF\u9996\u9875\u63A8\u8350\u6B4C\u5355","PAGE_RECOMMEND_SPECIAL_CLOUD_VILLAGE_PLAYLIST"],["\u9690\u85CF\u9996\u9875\u6700\u8FD1\u5E38\u542C","PAGE_RECOMMEND_SHORTCUT"],["\u9690\u85CF\u9996\u9875\u97F3\u4E50\u5408\u4F19\u4EBA","HOMEPAGE_MUSIC_PARTNER"],["\u9690\u85CF\u9996\u9875\u96F7\u8FBE\u6B4C\u5355","PAGE_RECOMMEND_RADAR"],["\u9690\u85CF\u9996\u9875\u6392\u884C\u699C","PAGE_RECOMMEND_RANK"],["\u9690\u85CF\u9996\u9875\u63A8\u8350\u4E13\u5C5E\u6B4C\u5355","PAGE_RECOMMEND_MY_SHEET"],["\u9690\u85CF\u9996\u9875\u4F60\u7684\u4E13\u5C5E\u6B4C\u5355","PAGE_RECOMMEND_COMBINATION"]].filter(([A,C])=>$persistentStore.read(A)!=="\u662F").map(([A,C])=>C))}var ke={PAGE_RECOMMEND_GREETING:0,PAGE_RECOMMEND_SPECIAL_CLOUD_VILLAGE_PLAYLIST:1,PAGE_RECOMMEND_DAILY_RECOMMEND:2,PAGE_RECOMMEND_SHORTCUT:3,HOMEPAGE_MUSIC_PARTNER:4,PAGE_RECOMMEND_RADAR:5,PAGE_RECOMMEND_RANK:6,PAGE_RECOMMEND_MY_SHEET:7,PAGE_RECOMMEND_COMBINATION:8},F;function Me(l){l.musicPackage&&(l.musicPackage&&(l.musicPackage.expireTime=V,l.musicPackage.vipLevel=7),l.associator&&(l.associator.expireTime=V,l.associator.vipLevel=7),l.voiceBookVip&&(l.voiceBookVip.expireTime=V,l.voiceBookVip.vipLevel=7),l.redplus={vipCode:300,expireTime:V,iconUrl:null,dynamicIconUrl:null,vipLevel:7,isSignDeduct:!1,isSignIap:!1,isSignIapDeduct:!1,isSign:!1},l.redVipLevel&&(l.redVipLevel=7))}try{if(p===null)throw new Error("\u89E3\u5BC6\u5931\u8D25: "+Ee);switch(Ee){case"/batch":let R=(r,m={})=>{p[r]?.data&&(p[r].data=m)};R("/api/comment/tips/v2/get",{count:0,offset:0,records:[]}),R("/api/social/event/bff/ad/resources"),R("/api/ad/get",{code:200,ads:{}});let A="/api/comment/feed/inserted/resources";p[A]?.data&&(p[A].data={},p[A].trp?.rules&&(p[A].trp.rules=[]));let C="/api/event/rcmd/topic/list";p[C]?.data?.topicList&&(p[C].data.topicList=[]);let h="/api/platform/song/bff/grading/song/order/entrance";p[h]?.data?.songOrderEntrance&&(p[h].data.songOrderEntrance={});let b="/api/v2/resource/comments";p[b]?.data?.comments&&p[b].data.comments.forEach(r=>{r.user?.followed===!1&&(r.user.followed=!0),r.user.vipRights=null,r.user.avatarDetail=null,r.userBizLevels=null,r.pendantData=null,r.tag.extDatas=[],r.tag.contentPicDatas=null});let D="/api/music-vip-membership/client/vip/info";p[D]?.data&&Me(p[D].data);break;case"/v2/resource/comment/floor/get":p.data?.ownerComment&&(p.data.ownerComment.user.vipRights=null,p.data.ownerComment.user.avatarDetail={},p.data.ownerComment.pendantData=null),p.data?.comments&&p.data.comments.forEach(r=>{r.user?.followed===!1&&(r.user.followed=!0),r.user.vipRights=null,r.user.avatarDetail=null,r.userBizLevels=null,r.pendantData=null,r.tag.extDatas=[],r.tag.contentPicDatas=null});break;case"/music-vip-membership/client/vip/info":Me(p.data);break;case"api/ad/get":p={code:200,ads:{}};break;case"/link/position/show/resource":p.data?.crossPlatformResource?.positionCode&&p.data.crossPlatformResource.positionCode==="MyPageBar"&&(p.data.crossPlatformResource={});break;case"/user/follow/users/mixed/get/v2":p.data?.records&&p.data.records.forEach(r=>{r.mutualFollowDay===null&&(r.showContent={message:"\u{1F4A2}\u4ED6/\u5979,\u672A\u5173\u6CE8\u4F60",time:1e12,active:!0,boxContent:{}})});break;case"/vipnewcenter/app/resource/newaccountpage":p.data&&(p.data.mainTitle.vipCurrLevel=7,p.data.mainTitle.imgUrl="",p.data.mainTitle.jumpUrl="",p.data.mainTitle.reachMaxLevel=!0,p.data.subTitle.carousels=[],p.data.buttonTitle={});break;case"/link/home/framework/tab":let o=[],x=!1,E=Ae();if(E==="Surge")if(typeof $argument<"u"&&$argument!=="")try{F=JSON.parse($argument);let r={MY:"\u6F2B\u6E38",DT:"\u52A8\u6001",TJ:"\u63A8\u8350",FX:"\u53D1\u73B0"};o=Object.keys(F).filter(m=>F[m]==0).map(m=>r[m])}catch{x=!0}else x=!0;else E==="Loon"?o=["\u9690\u85CF\u6F2B\u6E38\u6807\u7B7E","\u9690\u85CF\u52A8\u6001\u6807\u7B7E","\u9690\u85CF\u63A8\u8350\u6807\u7B7E","\u9690\u85CF\u53D1\u73B0\u6807\u7B7E"].filter(m=>$persistentStore.read(m)==="\u662F").map(m=>m.replace(/隐藏|标签/g,"")):x=!0;x&&(o=["\u6F2B\u6E38"]),p.data?.commonResourceList&&(p.data.commonResourceList=p.data.commonResourceList.filter(r=>!o.includes(r.title)),p.data.commonResourceList.forEach(r=>{r.title==="\u53D1\u73B0"&&(r.subCommonResourceList=r.subCommonResourceList.filter(m=>!["\u76F4\u64AD"].includes(m.title)))}));break;case"/song/play/more/list/v2":if(p.data?.bottomItem?.itemNodeList){let r=p.data.bottomItem.itemNodeList[0],m=r.find(k=>k.type==="effect"),c=r.indexOf(m);c!==-1&&(r.splice(c,1),r.unshift(m))}break;case"homepage/block/page":if(p.data?.blocks){for(let r=0;r<p.data.blocks.length;r++)if(p.data.blocks[r].showType==="BANNER"){p.data.blocks[r].extInfo.banners=p.data.blocks[r].extInfo.banners.filter(m=>!["\u6D3B\u52A8","\u5E7F\u544A"].includes(m.typeTitle));break}}break;case"/link/page/discovery/resource/show":if(p.data?.blockCodeOrderList)try{p.data.blockCodeOrderList=JSON.stringify(JSON.parse(p.data.blockCodeOrderList).filter(r=>!["PAGE_DISCOVERY_BANNER"].includes(r)))}catch{console.log("101123")}p.data?.blocks&&(p.data.blocks=p.data.blocks.filter(r=>!["PAGE_DISCOVERY_BANNER"].includes(r.bizCode)));break;case"/link/page/rcmd/resource/show":if(ge(),p.data?.blocks){if(p.data.blocks=p.data.blocks.filter(r=>j.includes(r.bizCode)),p.data.blocks.length>0){for(let r=0;r<p.data.blocks.length;r++)if(p.data.blocks[r].bizCode==="PAGE_RECOMMEND_GREETING"){Object.keys(p.data.blocks[r].dslData).forEach(m=>{p.data.blocks[r].dslData[m].commonResourceList&&(p.data.blocks[r].dslData[m].commonResourceList=p.data.blocks[r].dslData[m].commonResourceList.forEach(c=>{(c.summary||c.extraMap||c.title)&&(c.summary&&(c.summary=""),c.extraMap&&(c.extraMap={}),c.trp_id&&(c.trp_id=""),c.log&&(c.log={}),c.icon&&(c.icon=""),c.actionUrl&&(c.actionUrl=""),c.s_ctrp&&(c.s_ctrp=""),c.resourceType&&(c.resourceType=""))}))});break}}p.data.blocks.sort((r,m)=>ke[r.bizCode]-ke[m.bizCode])}if(p.data?.blockCodeOrderList)try{p.data.blockCodeOrderList=JSON.stringify(JSON.parse(p.data.blockCodeOrderList).filter(r=>j.includes(r)))}catch{}break;case"/link/page/rcmd/block/resource/multi/refresh":if(p.data&&(ge(),p.data=p.data.filter(r=>j.includes(r.blockCode)),p.data?.length>0)){for(let r=0;r<p.data.length;r++)if(p.data[r].blockCode==="PAGE_RECOMMEND_GREETING"){Object.keys(p.data[r].block.dslData).forEach(m=>{p.data[r].block.dslData[m].commonResourceList&&(p.data[r].block.dslData[m].commonResourceList=p.data[r].block.dslData[m].commonResourceList.forEach(c=>{(c.summary||c.extraMap||c.title)&&(c.summary&&(c.summary=""),c.extraMap&&(c.extraMap={}),c.trp_id&&(c.trp_id=""),c.log&&(c.log={}),c.icon&&(c.icon=""),c.actionUrl&&(c.actionUrl=""),c.s_ctrp&&(c.s_ctrp=""),c.resourceType&&(c.resourceType=""))}))});break}}break;default:$done({})}let l=Le(p);ve=Ce?{bodyBytes:l.buffer.slice(l.byteOffset,l.byteLength+l.byteOffset)}:{body:l}}catch(l){console.log(l.message)}finally{$done(ve)}})();