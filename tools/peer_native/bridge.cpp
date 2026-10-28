// Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
// libdatachannel owns TLS/DTLS/ICE/SCTP. No foreign thread calls into Lua.
#include <rtc/rtc.hpp>
#include <atomic>
#include <cstring>
#include <deque>
#include <map>
#include <mutex>

#ifdef _WIN32
#define RR_EXPORT extern "C" __declspec(dllexport)
#else
#define RR_EXPORT extern "C" __attribute__((visibility("default")))
#endif
struct Event { int kind; std::string a,b; };
struct Peer {
  std::mutex lock;
  std::deque<Event> events;
  size_t bytes=0;
  bool failed=false;
  std::shared_ptr<rtc::WebSocket> ws;
  std::shared_ptr<rtc::PeerConnection> pc;
  std::shared_ptr<rtc::DataChannel> dc;
  void put(int kind,std::string a={},std::string b={}) {
    std::lock_guard<std::mutex> guard(lock);
    if(failed)return;
    if(events.size()>=512 || bytes+a.size()+b.size()>2*1024*1024) {
      failed=true;events.clear();events.push_back({9,"Peer receive queue exceeded its limit.",""});return;
    }
    bytes+=a.size()+b.size();events.push_back({kind,std::move(a),std::move(b)});
  }
};
static std::mutex peersLock;
static std::map<int,std::shared_ptr<Peer>> peers;
static std::atomic<int> serial{0};
static std::shared_ptr<Peer> get(int id) {
  std::lock_guard<std::mutex> guard(peersLock);
  auto p=peers.find(id);return p==peers.end()?nullptr:p->second;
}
static std::string text(rtc::message_variant value) {
  if(auto s=std::get_if<std::string>(&value))return *s;
  auto &v=std::get<rtc::binary>(value);return std::string(reinterpret_cast<const char*>(v.data()),v.size());
}
static void channel(std::weak_ptr<Peer> weak,std::shared_ptr<rtc::DataChannel> dc) {
  if(dc->label()!="retro-peer-v1"){dc->close();return;}
  if(auto p=weak.lock()){std::lock_guard<std::mutex>guard(p->lock);if(p->dc && p->dc!=dc){dc->close();return;}p->dc=dc;}else return;
  dc->onOpen([weak](){if(auto p=weak.lock())p->put(6);});
  dc->onClosed([weak](){if(auto p=weak.lock())p->put(8);});
  dc->onMessage([weak](rtc::message_variant v){if(auto p=weak.lock())p->put(7,text(std::move(v)));});
  dc->onError([weak](std::string){if(auto p=weak.lock())p->put(8);});
}
RR_EXPORT int rr_version(){return 1;}
RR_EXPORT int rr_open(const char*url,const char*ticket,const char*ca) {
  if(!url || !ticket || std::strlen(ticket)>4096 || std::strncmp(url,"wss://",6)!=0)return -1;
  try {
    auto p=std::make_shared<Peer>();std::weak_ptr<Peer>w=p;
    rtc::WebSocket::Configuration c;c.protocols={"retro-peer-v1",std::string("auth.")+ticket};
    c.maxMessageSize=131072;c.connectionTimeout=std::chrono::seconds(10);c.pingInterval=std::chrono::seconds(15);c.maxOutstandingPings=2;
    if(ca && *ca)c.caCertificatePemFile=ca;
    p->ws=std::make_shared<rtc::WebSocket>(c);
    p->ws->onOpen([w](){if(auto p=w.lock())p->put(1);});
    p->ws->onClosed([w](){if(auto p=w.lock())p->put(3);});
    p->ws->onError([w](std::string){if(auto p=w.lock())p->put(9,"The secure relay connection failed.");});
    p->ws->onMessage([w](rtc::message_variant v){if(auto p=w.lock())p->put(2,text(std::move(v)));});
    int id=++serial;{std::lock_guard<std::mutex>guard(peersLock);peers[id]=p;}
    p->ws->open(url);return id;
  }catch(...){return -1;}
}
RR_EXPORT int rr_start(int id,int offer,const char*stun) {
  auto p=get(id);if(!p || p->pc)return -1;
  try {
    rtc::Configuration c;c.maxMessageSize=65536;
    if(stun && *stun)c.iceServers.emplace_back(stun);
    p->pc=std::make_shared<rtc::PeerConnection>(c);std::weak_ptr<Peer>w=p;
    p->pc->onLocalDescription([w](rtc::Description d){if(auto p=w.lock())p->put(4,std::string(d),d.typeString());});
    p->pc->onLocalCandidate([w](rtc::Candidate c){if(auto p=w.lock())p->put(5,std::string(c),c.mid());});
    p->pc->onDataChannel([w](std::shared_ptr<rtc::DataChannel>d){channel(w,d);});
    p->pc->onStateChange([w](rtc::PeerConnection::State s){if(s==rtc::PeerConnection::State::Failed || s==rtc::PeerConnection::State::Disconnected || s==rtc::PeerConnection::State::Closed)if(auto p=w.lock())p->put(8);});
    if(offer)channel(w,p->pc->createDataChannel("retro-peer-v1"));
    return 0;
  }catch(...){p->put(8);return -1;}
}
RR_EXPORT void rr_drop(int id) {
  auto p=get(id);if(!p)return;std::shared_ptr<rtc::DataChannel> dc;
  {std::lock_guard<std::mutex>guard(p->lock);dc=std::move(p->dc);}
  auto pc=std::move(p->pc);if(dc)dc->close();if(pc)pc->close();
}
RR_EXPORT int rr_signal(int id,int kind,const char*a,const char*b) {
  auto p=get(id);if(!p || !p->pc || !a || !b)return -1;
  try {if(kind==4)p->pc->setRemoteDescription(rtc::Description(a,b));else if(kind==5)p->pc->addRemoteCandidate(rtc::Candidate(a,b));else return -1;return 0;}catch(...){return -1;}
}
RR_EXPORT int rr_send(int id,int direct,const char*data,int size) {
  auto p=get(id);if(!p || !data || size<0 || size>131072)return -1;
  try {
    std::shared_ptr<rtc::Channel> c;
    {std::lock_guard<std::mutex>guard(p->lock);c=direct?std::static_pointer_cast<rtc::Channel>(p->dc):std::static_pointer_cast<rtc::Channel>(p->ws);}
    if(!c || !c->isOpen() || c->bufferedAmount()>1024*1024)return -1;
    c->send(std::string(data,size));return 0;
  }catch(...){return -1;}
}
RR_EXPORT int rr_poll(int id,int*kind,char*a,int asize,char*b,int bsize) {
  auto p=get(id);if(!p)return -1;std::lock_guard<std::mutex>guard(p->lock);
  if(p->events.empty())return 0;
  auto&e=p->events.front();if(!a || !b || !kind || asize<=int(e.a.size()) || bsize<=int(e.b.size()))return -2;
  *kind=e.kind;std::memcpy(a,e.a.c_str(),e.a.size()+1);std::memcpy(b,e.b.c_str(),e.b.size()+1);
  p->bytes-=std::min(p->bytes,e.a.size()+e.b.size());p->events.pop_front();return 1;
}
RR_EXPORT void rr_close(int id) {
  auto p=get(id);if(!p)return;
  {std::lock_guard<std::mutex>guard(peersLock);peers.erase(id);}
  if(p->ws)p->ws->forceClose();if(p->pc)p->pc->close();
}
