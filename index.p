/////////////////////////////////////////////////////////////////////////////
// Tiny Modern Pascal Forum v1.0
// ==========================================================================
//              Author: G.E. Ozz Nixon Jr.
// Inspiration: TinyPHPForum by Ralph Capper
/////////////////////////////////////////////////////////////////////////////

uses
        HTMLTools,
        Hashes,
        Compressions,
        Environment,
        INIFiles,
        Strings;

const
        CRLF=#13#10;

Var
        StrList,i18n:TStringList;
        config,avatar,sessions:TIniFile;
        Forum,Topic,Post:Longint;
        Action,Buffer,Skin,SiteName:String;
        ScriptRoot,Lang,User,Title,CookieSession,CookieCRC:String;
        isAdmin,uStat:Boolean;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure Initialization();
Var
        Cookie:TStringList;
        Users:TIniFile;
        Ws,Ts:String;

begin
        isAdmin:=False;
        ScriptRoot:=ExtractFilePath(Request.getFilename);
        Cookie.Init();
        Cookie.setDelimiter("&");
        Ws:=Request.GetCookie();
        Sessions.Init(ScriptRoot+"sessions.ini");
        While Ws<>'' do begin
                Ts:=trim(Fetch(Ws,';'));
                Cookie.SetDelimitedText(ts);
                If (Cookie.getValues("TMPFSESSID")!="") then begin
                        If Sessions.ReadInt64(Cookie.getValues("TMPFSESSID"),"expires",0)>TimeStamp then begin
                                lang:=Cookie.getValues("lang");
                                skin:=Cookie.getValues("skin");
                                CookieCRC:=Cookie.getValues("arc");
                                User:=Sessions.ReadString(Cookie.getValues("TMPFSESSID"),"user","");
                                If (CookieCRC<>CRCARC(Lang+Skin+User,2112)) then begin
                                        Lang:='';
                                        Skin:='';
                                        User:='';
                                        CookieCRC:='';
                                End
                                Else begin
                                        Ws:='';
                                        CookieSession:=Cookie.getValues("TMPFSESSID");
                                end;
                        End;
                End;
        End;
        Cookie.Free;
        StrList.Init();
        StrList.setDelimiter("&");
        StrList.SetDelimitedText(Request.GetQueryString());
        Config.Init(ScriptRoot+"config.ini");
        siteName:=Config.ReadString("global","siteName","TMPF Forum");
        avatar.Init(ScriptRoot+"users.ini"); // READ-ONLY
        if (lang=="") then lang:=StrList.getValues("lang");
        if not FileExists(scriptroot+"lang/"+lang) then lang:="";
        if (lang=="") then lang:=Config.ReadString("global","defaultlang","en");
        if (skin=="") then skin:=StrList.getValues("skin");
        if not FileExists(scriptroot+"image/skin/"+skin+"/style.css") then skin:="";
        if (skin=="") then skin:=Config.ReadString("global","defaultskin","blues");
        Forum:=StrToIntDef(StrList.getValues("f"),0);
        Topic:=StrToIntDef(StrList.getValues("t"),0);
        Post:=StrToIntDef(StrList.getValues("p"),0);
        Action:=StrList.getValues("action");
        i18n.Init();
        i18n.LoadFromFile(ScriptRoot+"lang/"+lang);
        If (User!="") then begin
                Users.Init(ScriptRoot+"users.ini");
                IsAdmin:=(Users.ReadInteger(Users.ReadString("global",User,""),"seclevel",0)==99);
                Users.Free;
        end;
        if (StrList.getValues("RL")!="") then begin
                If Sessions.ReadInt64(StrList.getValues("RL"),"expires",0)>TimeStamp then begin
                        User:=Sessions.ReadString(Strlist.getValues("RL"),"user","");
                End;
        End;
        Sessions.Free;
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
function DecompressPost(Filename:String):String;
var
        BFH:File;
        NumRead:Longint;
        Tmp:String;

begin
        AssignFile(BFH, scriptroot+Filename);
        Reset(BFH, 1);
        SetLength(Tmp, FileSize(BFH));
        BlockRead(BFH, Tmp[1], FileSize(BFH), NumRead);
        CloseFile(BFH);
        LH6Decompress(Tmp, Result);
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure CompressPost(Filename, Buf:String);
var
        BFH:File;
        NumWrite:Longint;
        Tmp:String;

begin
        LH6Compress(Buf, Tmp);
        Buf:='';
        AssignFile(BFH, scriptroot+Filename);
        Rewrite(BFH, 1);
        BlockWrite(BFH, Tmp[1], Length(Tmp), NumWrite);
        CloseFile(BFH);
End;

/////////////////////////////////////////////////////////////////////////////
// Mask our avatar sheet - could not do simple math - it is not symetrical
/////////////////////////////////////////////////////////////////////////////
function showAvatar(which:longint):String;
const
        xArray=["-10px","-84px","-158px","-232px","-306px","-380px","-454px","-528px"];
        yArray=["0px","-74px","-148px","-222px","-296px","-370px","-444px","-518px","-592px","-666px","-740px"];

var
        X,Y:Longint;

begin
        Y:=0;
        X:=(Which mod 8)-1;
        Y:=Which div 8;
        If X<0 then begin
                X:=7;
                If Y>0 then Dec(Y);
        End;
        result:="<div style='border-radius:40px;background:#0066AA url(image/avatars/face_avatars_full.png) "+XArray[x]+
                #32+yArray[y]+" no-repeat;margin-left:16px;height:70px;width:80px;border:1px solid #333;'></div>";
end;


/////////////////////////////////////////////////////////////////////////////
// Show HTML Header
/////////////////////////////////////////////////////////////////////////////
procedure showHTMLHeader(F:Longint);
var
        Tmp,D,K:String;
        Forums:TIniFile;

begin
        If F>0 then begin
                Tmp:="Forum"+IntToStr(F);
                Forums.Init(ScriptRoot+"forums.ini");
                D:=Forums.ReadString(Tmp,"description","");
                K:=Forums.ReadString(Tmp,"keywords","");
                Forums.Free;
        end
        else begin
                D:=Config.ReadString("global","description","");
                K:=Config.ReadString("global","keywords","");
        end;
        Response.Writeln("<!DOCTYPE html>"+CRLF+
                "<html><head>"+CRLF+
                "<link rel='shortcut icon' href='./favicon.ico'>"+CRLF+
                "<title>"+siteName+"</title>"+CRLF+
                "<meta name='description' content='"+D+"'>"+CRLF+
                "<meta name='keywords' content='"+K+"'>"+CRLF+
                "<meta name='ROBOTS' content='"+Config.ReadString("global","robots","INDEX, FOLLOW")+"'>"+CRLF+
                "<meta name='revisit-after' content='3 days'>"+CRLF+
                "<meta http-equiv='content-type' content='text/html; charset=utf-8'>"+CRLF+
                "<meta http-equiv='refresh' content='"+Config.ReadString("global","cookietm","10800")+"URL:./?action=logout'>"+CRLF+
                "<link rel='stylesheet' type='text/css' href='image/skin/"+Skin+"/style.css'>"+CRLF+
                "<script src='https://www.google.com/recaptcha/api.js' async defer></script>"+CRLF+
                "<script src='js/popup.js' type='text/javascript' charset='utf-8'></script>"+CRLF+
                "<script src='js/nicEdit.js' type='text/javascript'></script>"+CRLF+
                "<script type='text/javascript'>bkLib.onDomLoaded(function() { if (!areCookiesEnabled()) { alert('Cookies are required!'); }"+
                " try { new nicEditor({fullPanel:true,maxHeight:400,iconsPath:'./nicEditorIcons.gif'}).panelInstance('txteditor'); } catch(err) {}});</script>"+CRLF+
                "</head>");
        D:="image/skin/"+Skin+"/logo.png";
        If not FileExists(scriptroot+D) then D:="image/skin/"+Skin+"/logo.jpg";
        If not FileExists(scriptroot+D) then D:="image/skin/"+Skin+"/logo.gif";
        If not FileExists(scriptroot+D) then D:="<H1>"+siteName+"</H1>"
        Else D:="<img src='"+D+"' alt='Home'>";
        Response.Writeln("<body style='margin:0em auto;text-align:center'>"+CRLF+
                "<table class='centerbody'>"+CRLF+
                "<tr><td class='mainlogo' colspan='2'>"+
                "<a href='"+Config.ReadString("global","siteURL","./")+"'>"+D+"</a>"+
                "</td></tr>"+CRLF+
                "<tr><td class='tp'>");
end;

/////////////////////////////////////////////////////////////////////////////
// Show a list of forums
/////////////////////////////////////////////////////////////////////////////
procedure showForums();
var
        Forums:TIniFile;
        Tmp:String;

begin
        Response.Writeln("<div class='barre'>"+Config.ReadString("global","title",siteName)+"</div>"+CRLF+
                "<table class='tablewide'>"+CRLF+
                "<tr>"+
                "<td class='col1tp'>"+i18n.getValues('l_forumCol1')+"</td>"+
                "<td class='col2tp'>"+i18n.getValues('l_forumCol2')+"</td>"+
                "<td class='col3tp'>"+i18n.getValues('l_forumCol3')+"</td>"+
                "<td class='col4tp'>"+i18n.getValues('l_forumCol4')+"</td>"+
                "</tr>");
        Forums.Init(ScriptRoot+"forums.ini");
        for var i:=1 to Forums.ReadInteger("global","count",0) do begin
                Tmp:="forum"+IntToStr(I);
                Response.Write("<tr><td class='filler' colspan='4'></td></tr>"+CRLF+
                        "<tr>"+
                        "<td class='col1bt'><a class='topicLink' href='./?f="+IntToStr(I)+"&amp;lang="+lang+"&amp;skin="+skin+"'>"+
                        Forums.ReadString(Tmp,"name","unknown")+"</a></td>"+CRLF+
                        "<td class='col2bt'>"+Forums.ReadString(Tmp,"topics","0")+"</td>"+
                        "<td class='col3bt'>"+Forums.ReadString(Tmp,"lastposted","-")+"</td>"+CRLF+
                        "<td class='col4bt'>"+Forums.ReadString(Tmp,"lastposter","-"));
                if (Forums.ReadString(Tmp,"lastpost","") != "") then Response.Write("&nbsp;<a href='./?"+Forums.ReadString(Tmp,"lastpost","f=1&amp;t=1&amp;p=1")+
                        "&amp;lang="+lang+"&amp;skin="+skin+"'><img src='image/skin/"+Skin+"/lastpost.png' alt='Go'></a>");
                Response.Write("</td>"+
                        "</tr>"+CRLF+
                        "<tr>"+CRLF+
                        "<td class='coltxt' colspan='4'>");
                if (isAdmin) then Response.Write("<a class='optionLink' href='./?action=edit&amp;f="+IntToStr(I)+
                        "&amp;t=-1&amp;lang="+lang+"&amp;skin="+skin+"'>"+i18n.getValues('l_edit')+" &gt;</a>");
                Response.Writeln(Forums.ReadString(Tmp,"description","")+
                        "</td>"+
                        "</tr>");
        end;
        Forums.Free;
        Response.Writeln("<tr><td class='filler' colspan='4'></td></tr>"+CRLF+
                "</table>");
        if (isAdmin) then buffer:="<a class='barreLien' href='./?action=edit&amp;f=-1&amp;lang="+lang+"&amp;skin="+skin+"'>"+i18n.getValues('l_forumNew')+"</a> | ";
end;

/////////////////////////////////////////////////////////////////////////////
// Show all topics in this forum
/////////////////////////////////////////////////////////////////////////////
procedure showTopics(F:Longint);
var
        Topics,Forums:TIniFile;
        Tmp:String;

begin
        Forums.Init(scriptroot+"forums.ini");
        Topics.Init(scriptroot+"forums/"+IntToStr(F)+"/topics.ini");
        Response.Writeln("<div class='barre'>"+
                "<a class='barreLien' href='./'>"+Config.ReadString("global","title",siteName)+"</a>/"+Forums.ReadString("forum"+IntToStr(F),"name","unnamed")+
                "</div>"+CRLF+
                "<table class='tablewide'>"+CRLF+
                "<tr>"+
                "<td class='col1ttp'>"+i18n.getValues('l_topicCol1')+"</td>"+
                "<td class='col3ttp'>"+i18n.getValues('l_topicCol2')+"</td>"+
                "<td class='col2ttp'>"+i18n.getValues('l_topicCol3')+"</td>"+
                "<td class='col2ttp'>"+i18n.getValues('l_topicCol4')+"</td>"+
                "<td class='col3ttp'>"+i18n.getValues('l_topicCol5')+"</td>"+
                "<td class='col4ttp'>"+i18n.getValues('l_topicCol6')+"</td>"+
                "</tr>");

        For var I:=1 to Topics.ReadInteger("global","count",0) do begin
                Tmp:="topic"+IntToStr(I);
                Response.Writeln("<tr><td class='filler' colspan='6'></td></tr>"+CRLF+
                        "<tr>"+CRLF+
                        "<td class='col1bt'>"+
                        "<a class='topicLink' href='./?f="+IntToStr(F)+"&amp;t="+IntToStr(I)+"&amp;lang="+lang+"&amp;skin="+skin+"'>"+Topics.ReadString(Tmp,"name","unnamed")+"</a>"+
                        "</td>"+CRLF+
                        "<td class='col3tbt'>"+Topics.ReadString(Tmp,"creator","-")+"</td>"+CRLF+
                        "<td class='col2tbt'>"+Topics.ReadString(Tmp,"count","0")+"</td>"+CRLF+
                        "<td class='col3tbt'>"+Topics.ReadString(Tmp,"views","0")+"</td>"+CRLF+
                        "<td class='col4tbt'>"+Topics.ReadString(Tmp,"lastposted","-")+"</td>"+CRLF+
                        "<td class='col5tbt'>"+Topics.ReadString(Tmp,"lastposter","-"));
                if (Topics.ReadString(Tmp,"lastpost","") != "") then Response.Write(" <a href='./?"+
                        Forums.ReadString(Tmp,"lastpost","f="+IntToStr(F)+"&amp;t="+IntToStr(I)+"&amp;p=1")+
                        "&amp;lang="+lang+"&amp;skin="+skin+"'><img src='image/skin/"+Skin+"/lastpost.png' alt='Go'></a>");
                Response.Writeln("</td>"+CRLF+
                        "</tr>"+CRLF+
                        "<tr>"+CRLF+
                        "<td class='coltxt' colspan='6'>"+Topics.ReadString(Tmp,"description",""));
                if (isAdmin) then begin
                        Response.Writeln("<a class='optionLink' href='./?action=edit&amp;f="+IntToStr(F)+
                                 "&amp;t="+IntToStr(I)+"&amp;p=-2&amp;lang="+lang+"&amp;skin="+skin+"'>["+i18n.getValues('l_edit')+"]</a></td>"+CRLF+"</tr>");
                end
                else begin
                        Response.Writeln("&nbsp;</td>"+CRLF+"</tr>");
                end;
        end;
        Response.Writeln("<tr><td class='filler' colspan='6'></td></tr>"+CRLF+
                "</table>");
        if (isAdmin) then buffer:="<a class='barreLien' href='./?action=edit&amp;f="+IntToStr(F)+"&amp;p=-1&amp;lang="+
                lang+"&amp;skin="+skin+"'>"+i18n.getValues('l_topicNew')+"</a> | ";
        Topics.Free;
        Forums.Free;
        Forums.Init(scriptroot+"forums.ini");
        Forums.WriteInteger("forum"+IntToStr(F),"views", Forums.ReadInteger("forum"+IntToStr(F),"views",0)+1);
        Forums.Free;
end;

/////////////////////////////////////////////////////////////////////////////
// Show all posts in this forum/topic
/////////////////////////////////////////////////////////////////////////////
procedure showPosts(f,t:Longint);
var
        Forums,Topics:TIniFile;
        Posts:TIniFile;
        TmpBool:Boolean;
        Tmp:String;

begin
        Forums.Init(scriptroot+"forums.ini");
        Topics.Init(scriptroot+"forums/"+IntToStr(F)+"/topics.ini");
        Response.Writeln("<div class='barre'><a class='barreLien' href='./'>"+Config.ReadString("global","title",siteName)+"</a>/"+
                "<a class='barreLien' href='./?f="+IntToStr(F)+"'>"+Forums.ReadString("forum"+IntToStr(F),"name","unnamed")+"</a>/"+
                Topics.ReadString("topic"+IntToStr(T),"name","unnamed")+"</div>"+CRLF+
                "<table class='tablewide'>");
                //"<tr><td class='filler' colspan='2'></td></tr>");
        TmpBool:=False;
        For var I:=1 to Topics.ReadInteger("topic"+IntToStr(T), "count", 0) do begin
                If not FileExists(scriptroot+"forums/"+IntToStr(F)+"/"+IntToStr(T)+"/"+IntToStr(I)+".ini") then continue;
                if (TmpBool) then Response.Writeln("<tr><td class='filler' colspan='2'></td></tr>");
                TmpBool:=True;
                Posts.Init(scriptroot+"forums/"+IntToStr(F)+"/"+IntToStr(T)+"/"+IntToStr(I)+".ini");
                Tmp:=Posts.ReadString("header","poster","Guest");
                Response.Writeln("<tr>"+CRLF+
                        "<td class='foruml'>"+CRLF+
                        "<a id='x"+IntToStr(I)+"'></a>"+
                        showAvatar(avatar.ReadInteger(avatar.ReadString("global", Tmp, "guest"), "avatar", 88))+"<br>"+
                        Tmp+
// !!more user details here!! //
                        "<br><span class='little'>"+Posts.ReadString("header","posted","-")+"</span>");
                if (Posts.ReadString("header","edited","")!="") then begin
                        Tmp:=Posts.ReadString("header","editer","admin");
                        Response.Writeln("<hr>"+i18n.getValues('l_actionEdited')+"<br>"+
                                showAvatar(avatar.ReadInteger(avatar.ReadString("global", Tmp, "admin"), "avatar", 88))+"<br>"+
                                Tmp+"<br><span class='little'>"+Posts.ReadString("header","edited","-")+"</span>");
                end;
                Response.Writeln("</span></td>"+CRLF+
                        "<td class='courant'>"+DecompressPost("forums/"+IntToStr(F)+"/"+IntToStr(T)+"/"+IntToStr(I))+"</td>"+CRLF+
                        "</tr>");
                if (User!="Guest") then begin
                        Response.Writeln("<tr><td class='foruml'></td><td class='options'>");
                                Response.Writeln("<a class='optionLink' href='./?f="+IntToStr(F)+""+
                                        "&amp;t="+IntToStr(T)+"&amp;p="+IntToStr(I)+"&amp;lang="+lang+"&amp;skin="+skin+"#x"+IntToStr(I)+"'>Link to this post</a>");
                        if (User==Posts.ReadString("header","poster","Guest")) or (IsAdmin) then begin
                                Response.Writeln(" | <a class='optionLink' href='./?action=edit&amp;f="+IntToStr(F)+""+
                                        "&amp;t="+IntToStr(T)+"&amp;p="+IntToStr(I)+"&amp;lang="+lang+"&amp;skin="+skin+"'>"+i18n.getValues('l_edit')+"</a>");
                                If (isAdmin) then begin
                                        Response.Writeln(" | <a class='optionLink' href='./?action=split&amp;f="+
                                                IntToStr(F)+"&amp;t="+IntToStr(T)+"&amp;p="+IntToStr(I)+"&amp;lang="+lang+"&amp;skin="+skin+"'>"+
                                                i18n.getValues('l_split')+"</a>");
                                end;
                        end;
                        Response.Writeln("</td></tr>");
                end;
                Posts.WriteInteger("header","views", Topics.ReadInteger("header","views",0)+1);
                Posts.Free;
        End;
        Response.Writeln("<tr><td class='filler' colspan='2'></td></tr>"+CRLF+
                "</table>");
        if (isAdmin) or (Topics.ReadBoolean("topic"+IntToStr(T),"userscreate",false)) then
                buffer:="<a class='barreLien' href='./?action=edit&amp;f="+IntToStr(F)+"&amp;t="+IntToStr(T)+"&amp;p=0&amp;lang="+lang+"&amp;skin="+skin+"'>"+
                        i18n.getValues('l_postReply')+"</a> | ";
        Forums.Free;
        Topics.Free;
        Topics.Init(scriptroot+"forums/"+IntToStr(F)+"/topics.ini");
        Topics.WriteInteger("topic"+IntToStr(T),"views", Topics.ReadInteger("topic"+IntToStr(T),"views",0)+1);
        Topics.Free;
end;

/////////////////////////////////////////////////////////////////////////////
// New post - Where we post depends on values of $f, $t and $p
/////////////////////////////////////////////////////////////////////////////
procedure newPost(F,T,P:Longint);
var
        Forums,Topics,Posts:TIniFile;
        Tmp,Txt:String;

begin
        if (f>0) then begin
                Forums.Init(ScriptRoot+"forums.ini");
                Response.Writeln("<div class='barre'><a class='barreLien' href='./'>"+
                        Config.ReadString("global","title",siteName)+"</a> | <a class='barreLien' href='./?f="+
                        IntToStr(F)+"'>"+Forums.ReadString("forum"+IntToStr(F),"name","unnamed")+"</a></div>");
                Forums.Free;
        End;
        if (isAdmin) or ((StrList.getValues("f")!="") and (StrList.getValues("t")!="") and (StrList.getValues("p")!="")) then begin
                Response.Writeln("<form action='./?action=new' method='POST'>"+CRLF+
                        "<input type='hidden' name='lid' value='"+lang+"'>"+CRLF+
                        "<input type='hidden' name='fid' value='"+IntToStr(F)+"'>"+CRLF+
                        "<input type='hidden' name='tid' value='"+IntToStr(T)+"'>"+CRLF+
                        "<input type='hidden' name='pid' value='"+IntToStr(P)+"'>");
                // Post new post within new topic
                if (f>0) and (p==-1) then begin
                        //confirm can post!
                        Response.Writeln("<div class='editionDark'>"+i18n.getValues('l_newPostTopic')+"</div>"+CRLF+
                                "<div class='editionLight'> "+
                                i18n.getValues('l_topicCol1')+": <input type='text' name='tname' value='' size='40' maxLength='36'> | "+
                                i18n.getValues('l_newPostTopicHead')+"<br>"+CRLF+
                                "Description: <input type='text' name='txt2' value='' size='80' maxLength='80'>");
                        Response.Writeln("</div>"+CRLF+
                                "<div class='editionLightEditor'>"+CRLF+
                                "<textarea rows=15 cols=110 name='txt' id='txteditor'></textarea>"+CRLF+
                                "<input type='hidden' name='action' value='npostntopic'>"+CRLF+
                                "</div>");
                end
                // Post new post within this topic
                else if (f>0) and (t>0) and (p==0) then begin
                        Topics.Init(scriptroot+"forums/"+IntToStr(F)+"/topics.ini");
                        //confirm can post!
                        Response.Writeln("<div class='editionDark'>"+i18n.getValues('l_newPost')+"</div>"+CRLF+
                                "<div class='editionLightEditor'>  "+
                                i18n.getValues('l_topicCol1')+": "+
                                Topics.ReadString("topic"+IntToStr(T),"name","unnamed")+
                                "<hr><textarea class='panelContain' rows=15 cols=110 name='txt' id='txteditor'>"+{i18n.getValues('l_newPostType')+}"</textarea>"+CRLF+
                                "<input type='hidden' name='action' value='npost'>"+CRLF+
                                "</div>");
                        Topics.Free;
                end
                // Edit post within this topic
                else if (f>0) and (t>0) and (p>0) then begin
                        Topics.Init(scriptroot+"forums/"+IntToStr(F)+"/topics.ini");
                        Posts.Init(scriptroot+"forums/"+IntToStr(F)+"/"+IntToStr(T)+"/"+IntToStr(P)+".ini");
                        //confirm can edit!
                        Response.Writeln("<div class='editionDark'>"+i18n.getValues('l_editPost')+" #"+IntToStr(P)+"</div>"+CRLF+
                                "<div class='editionLight'> "+
                                i18n.getValues('l_topicCol1')+": "+
                                Topics.ReadString("topic"+IntToStr(T),"name","unnamed")+
                                "</div>"+CRLF+
                                "<div class='editionDark'>"+CRLF+
                                " "+i18n.getValues('l_editPostWarn')+" <input type='checkbox' name='delete'>"+
                                "</div>"+CRLF+
                                "<div class='editionLightEditor'>"+CRLF+
                                "<textarea class='panelContain' rows=15 cols=110 name='txt' id='txteditor'>"+
                                DecompressPost("forums/"+IntToStr(F)+"/"+IntToStr(T)+"/"+IntToStr(P))+"</textarea>"+CRLF+
                                "<input type='hidden' name='action' value='epost'>"+CRLF+
                                "</div>");
                        Posts.WriteInteger("header","views", Posts.ReadInteger("header","views",0)+1);
                        Posts.Free;
                        Topics.Free;
                end
                // New forum
                else if (f<0) then begin
                        //confirm can create!
                        Response.Writeln("<div class='barre'><a class='barreLien' href='./'>"+siteName+"</a> | "+i18n.getValues('l_newForum')+"</div>"+CRLF+
                                "<div class='editionLightEditor'>"+CRLF+
                                i18n.getValues('l_newForumName')+":<br><input type='text' name='fname' value='' size='40' maxLength='36'>"+CRLF+
                                "<hr>"+i18n.getValues('l_newForumDesc')+":<br><textarea rows=3 cols=110 name='txt' id='txteditor'></textarea>"+CRLF+
                                "[meta keywords]:<br><input type='text' name='fkwords' value='' size='80' maxLength='80'> | (comma delimited)<br>"+CRLF+
                                "Users can create topics? <input type='checkbox' name='delete' checked='checked'>"+CRLF+
                                "<input type='hidden' name='action' value='nforum'>"+CRLF+
                                "</div>");
                end
                // Edit forum details
                else if (f>0) and (t<0) then begin
                        //confirm can edit!
                        Forums.Init(ScriptRoot+"forums.ini");
                        Response.Writeln("<div class='editionDark'><h2>"+i18n.getValues('l_editForum')+" #"+IntToStr(F)+"</div>"+CRLF+
                                "<div class='editionLight'>"+CRLF+
                                "#ID <input type='text' name='fid2' size=6 maxlength=6 value='"+IntToStr(F)+"'> "+i18n.getValues('l_editForumID')+"<br>"+CRLF+
                                i18n.getValues('l_editForumWarn')+" <input type='checkbox' name='delete'><hr>"+CRLF+
                                "<table class='widetable'><tr><td>"+
                                i18n.getValues('l_forumCol1')+"Forum Name</td><td><input type='text' name='fname' value='"+
                                Forums.ReadString("forum"+IntToStr(F),"name","")+"' size='40' maxLength='36'></td></tr>"+CRLF+
                                "<tr><td>"+i18n.getValues('l_newForumDesc')+"</td><td><input type='text' name='txt' size=70 maxlength=180 value='"+
                                Forums.ReadString("forum"+IntToStr(F),"description","")+"'></td></tr></table>"+CRLF+
                                "<input type='hidden' name='action' value='eforum'>"+CRLF+
                                "</div>");
                        Forums.Free;
                end
                // Edit topic details
                else if (f>0) and (t>0) and (p==-2) then begin
                        Topics.Init(ScriptRoot+"forums/"+IntToStr(F)+"/topics.ini");
                        Response.Writeln("<div class='editionDark'><h2>"+i18n.getValues('l_editTopic')+" #"+IntToStr(T)+"</h2></div>"+CRLF+
                                "<div class='editionLight'>"+CRLF+
                                i18n.getValues('l_editTopicWarn')+" <input type='checkbox' name='delete'><hr>"+CRLF+
                                "<table class='widetable'><tr><td>"+
                                i18n.getValues('l_topicCol1')+"</td><td><input type='text' name='tname' value='"+
                                Topics.ReadString("topic"+IntToStr(T),"name","")+"' size='40' maxLength='34'> | "+
                                i18n.getValues('l_newPostTopicHead')+"</td></tr>"+CRLF+
                                "<tr><td>"+i18n.getValues('l_newForumDesc')+"</td><td><input type='text' name='txt' size=70 maxlength=180 value='"+
                                Topics.ReadString("Topic"+IntToStr(T),"description","")+"'></td></tr></table>"+CRLF+
                                "<input type='hidden' name='action' value='etopic'>"+CRLF+
                                "</div>");
                        Topics.Free;
                end;
                Response.Writeln("<div class='editionLight'>"+CRLF+
                        "<input type='submit' value='OK'>"+
                        // Shows formatting options
                        //" | <a class='link' href=&quot;javascript:popup('formathelp.php')&quot;>"+i18n.getValues('l_formatHelp')+"</a>"+CRLF+
                        " | <a class='link' href='./?f="+IntToStr(Forum)+"&amp;t="+IntToStr(topic)+"&amp;p="+IntToStr(post)+"'>Cancel</a>"+CRLF+
                        "</div>"+CRLF+
                        "</form>");
        End
        else begin
                Response.Writeln("<br><div class='quote'>"+i18n.getValues('l_guestError')+"<div>");
        end;
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure showMenu();
begin
        Response.Writeln("</td>"+CRLF+
                "<td class='menuContainer'>"+CRLF+
                "<div class='barre' style='text-align:center;'>"+i18n.getValues('l_menu')+"</div>"+CRLF+
                "<div class='menu'>"+CRLF+
                "<form action='./?action=search' method='GET'>"+CRLF+
                i18n.getValues('l_menuSearch')+
                "<br><input class='search' type='text' name='query' size='12' value='"+i18n.getValues('l_menuSearch')+
                "' onfocus='if (value==&quot;"+i18n.getValues('l_menuSearch')+"&quot;) { value =&quot;&quot; ;}' onblur='if (value == &quot;&quot;) {value = &quot;"+
                i18n.getValues('l_menuSearch')+"&quot; }' >"+CRLF+
                "</form>");
        if (User!="") and (User!="Guest") then begin
                Response.Write("<br><hr>"+
                        showAvatar(avatar.ReadInteger(avatar.ReadString("global", User, "guest"), "avatar", 88))+"<br>"+
                        i18n.getValues('l_menuWelcome')+" "+User);
                If (IsAdmin) then Response.Write("<B>*</B>");
                Response.Writeln("<div class='logout'>"+
                        "<a class='link' href='./?action=logout&amp;f="+IntToStr(Forum)+"&amp;t="+IntToStr(Topic)+
                        "&amp;p="+IntToStr(Post)+"'>"+i18n.getValues('l_menuLogout')+"</a><br>"+CRLF+
                        "<a class='link' href='./?action=profile&amp;f="+IntToStr(Forum)+
                        "&amp;t="+IntToStr(Topic)+"&amp;p="+IntToStr(Post)+"'>"+i18n.getValues('l_menuProfil')+"</a>"+CRLF+
                        "</div>");
        end
        else begin
                Response.Writeln("<br><hr><form action='./?action=login' method='POST'>"+CRLF+
                        i18n.getValues('l_menuLogin')+"<br>"+CRLF+
                        "<input class='username' type='text' name='user' size='12' value='"+i18n.getValues('l_menuUsername')+
                        "' onfocus='if (value == &quot;"+i18n.getValues('l_menuUsername')+"&quot;) {value =&quot;&quot; }' "+
                        "onblur='if (value == &quot;&quot;) { value = &quot;"+i18n.getValues('l_menuUsername')+"&quot; }'><br>"+CRLF+
                        "<input class='password' type='password' name='passwd' size='12' value='Password' "+
                        "onfocus='if (value == &quot;Password&quot;) { value=&quot;&quot; }' "+
                        "onblur='if (value == &quot;&quot;) { value = &quot;Password&quot; }'><br>"+CRLF+
                        "<input type='hidden' name='lid' value='"+lang+"'>"+CRLF+
                        "<input type='hidden' name='fid' value='"+IntToStr(Forum)+"'>"+CRLF+
                        "<input type='hidden' name='tid' value='"+IntToStr(Topic)+"'>"+CRLF+
                        "<input type='hidden' name='pid' value='"+IntToStr(Post)+"'>"+CRLF+
                        "<input type='submit' value='OK'>"+CRLF+
                        " | <a class='link' href='./?f="+IntToStr(Forum)+"&amp;t="+IntToStr(topic)+"&amp;p="+IntToStr(post)+"'>Cancel</a>"+CRLF+
                        "</form>");
                if Config.ReadBoolean("global","allowNewUser",true) then Response.Writeln("<br><hr><div class='signup'>"+
                        "<a class='link' href='./?action=profile'>"+i18n.getValues('l_menuNewUser')+"</a></div>");
        end;
(*
                  // Show list of forums on right
                  echo $GLOBALS['l_menuQuick']."<br>\n";
                  echo "<div class='quote'>\n";
                  showMiniForums();
                  echo "</div>\n";
                  // Membership list
                  echo "<div class='quote'>\n";
                  echo "<a class='link' href='profile.php?action=all'>".$GLOBALS['l_menuMembers']."</a>\n";
                  echo "</div>\n";

                  // !!!Chat MOD!!!
                  //echo "<div class='quote'>\n";
                  //echo "<a class='link' href=\"javascript:popup('chat.php')\">Chat!</a>\n";
                  //echo "</div>\n";

                  // Members on-line
                  $mems=getUsersOnLine();
                  if (!empty($mems))
                  {
                                         echo $GLOBALS['l_menuOnLine']."<br>\n";
                                         echo "<div class='quote'>\n";
                                         for ($i=0; $i<count($mems); $i++)
                                         {
                                                                echo "<a class='link' href='profile.php?action=view&amp;uname=".$mems[$i]->user."'>".$mems[$i]->user."</a>";
                                                                echo "<br>\n";
                                         }
                                         echo "</div>\n";
                  }
                  ?>
*)
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure showFooter();
begin
        Response.Write("</div>"+CRLF+
                "</td>"+CRLF+
                "</tr>"+CRLF+
                "<tr>"+
                "<td colspan='2'>"+
                "<div class='barre'>"+
                buffer+
                "<a class='barreLien' href='#top'>"+i18n.getValues('l_top')+"</a>"+
                "</div>"+CRLF+
                "<div class='footer'>"+
                "Powered by <a class='minilink' href='http://www.modernpascal.com/'>Tiny Modern Pascal Forum</a> v"+
                Config.ReadString("global","version","4.0")+" &copy;2015<br />"+CRLF+
                "<a class='minilink' href='mailto:"+Config.ReadString("global","email","")+"'>email</a> | "+CRLF+
                "<a class='minilink' href='http://jigsaw.w3.org/css-validator/check/referer'>CSS Valid</a> | "+CRLF+
                "<a class='minilink' href='http://validator.w3.org/check?uri=referer'>HTML 5.0 Valid</a>");
        if Config.ReadBoolean("global","hitcounter",true) then
                Response.Write(" | "+i18n.getValues('l_topicCol4')+": "+Config.ReadString("global","hits","1"));
        Response.Writeln(CRLF+"</div>"+CRLF+
                "</td>"+CRLF+
                "</tr>"+CRLF+
                "<tr><td colspan='2'><a id='bot'></a></td></tr>");
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure savePost(F,T,P:Longint);
var
        L, NextMsg:Longint;
        Fid, Tid, Pid, Fid2:Longint;
        Usr, Lng, Act:String;
        txt, sha, sha2:String;
        Forums, Topics, Posts:TIniFile;

begin
        StrList.SetDelimitedText(Request.GetPostData());
        Act:=StrList.getValues("action");
        Usr:=StrList.getValues("uid");
        Lng:=StrList.getValues("lid");
        Txt:=StrList.getValues("txt");
        Fid:=StrToIntDef(StrList.getValues("fid"),0);
        Tid:=StrToIntDef(StrList.getValues("tid"),0);
        Pid:=StrToIntDef(StrList.getValues("pid"),0);
        Fid2:=StrToIntDef(StrList.getValues("fid2"),0);
        If (User=="") and (Usr=="") then User:="Guest"
        else begin
                 If (User=="") then User:=Usr;
// lookup user!
        end;
        Forums.Init(scriptroot+"forums.ini");
        If (Fid>0) then begin
                If (Forums.ReadString("forum"+StrList.getValues("fid"),"name","")!="") then begin
                        If (Tid>0) then begin
                                Topics.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/topics.ini");
                                If (Topics.ReadString("topic"+StrList.getValues("tid"),"name","")!="") then begin
                                        If (Pid=0) then begin
                                                if (isAdmin) or (Topics.ReadBoolean("topic"+IntToStr(T),"userscreate",false)) then begin
                                                        Sha:=Topics.ReadString("topic"+StrList.getValues("tid"),"sha256","");
                                                        Txt:=EscapeDecode(Txt);
                                                        Sha2:=SHA256(Txt);
                                                        If (Sha<>Sha2) then begin
                                                                NextMsg:=Topics.ReadInteger("topic"+StrList.getValues("tid"),"count",0)+1;
                                                                Topics.Free;
                                                                Topics.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/topics.ini");
                                                                Topics.WriteInteger("topic"+StrList.getValues("tid"),"count",NextMsg);
                                                                Topics.WriteString("topic"+StrList.getValues("tid"),"sha256",sha2);
                                                                Posts.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/"+StrList.getValues("tid")+"/"+IntToStr(NextMsg)+".ini");
                                                                Posts.WriteString("header","name", Topics.ReadString("topic"+StrList.getValues("tid"),"name",""));
                                                                Posts.WriteInteger("header","count",0);
                                                                Posts.WriteInteger("header","views",0);
                                                                Posts.WriteInt64("header","posted",Timestamp);
                                                                Posts.WriteString("header","poster",User);
                                                                Posts.Free;
                                                                CompressPost("forums/"+StrList.getValues("fid")+"/"+StrList.getValues("tid")+"/"+IntToStr(NextMsg),Txt);
                                                        End;
Response.Redirect("./?f="+IntToStr(Fid)+"&t="+IntToStr(Tid)+"&p="+IntToStr(Pid)+"&lang="+lang+"&skin="+skin);
//                                                      ShowPosts(Fid, Tid);
                                                end;
                                        End
                                        else if (Pid>0) then begin
                                                if (StrList.getValues("delete")=="on") then begin
                                                        DeleteFile(scriptroot+"forums/"+StrList.getValues("fid")+"/"+StrList.getValues("tid")+"/"+StrList.getValues("pid"));
                                                        DeleteFile(scriptroot+"forums/"+StrList.getValues("fid")+"/"+StrList.getValues("tid")+"/"+StrList.getValues("pid")+".ini");
                                                end
                                                else begin
                                                        Sha:=Topics.ReadString("topic"+StrList.getValues("tid"),"sha256","");
                                                        Txt:=EscapeDecode(Txt);
                                                        Sha2:=SHA256(Txt);
                                                        If (Sha<>Sha2) then begin
                                                                Posts.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/"+StrList.getValues("tid")+"/"+StrList.getValues("pid")+".ini");
                                                                Posts.WriteInt64("header","edited",Timestamp);
                                                                Posts.WriteString("header","editer",User);
                                                                Posts.Free;
                                                                CompressPost("forums/"+StrList.getValues("fid")+"/"+StrList.getValues("tid")+"/"+StrList.getValues("pid"),Txt);
                                                                Topics.WriteString("topic"+StrList.getValues("tid"),"sha256",sha2);
                                                        End;
                                                end;
Response.Redirect("./?f="+IntToStr(Fid)+"&t="+IntToStr(Tid)+"&p="+IntToStr(Pid)+"&lang="+lang+"&skin="+skin);
//                                              ShowPosts(Fid, Tid);
                                        end
                                        else if (pid==-2) then begin
                                                if (StrList.getValues("delete")=="on") then begin
                                                end
                                                else begin
                                                        Topics.WriteString("topic"+StrList.GetValues("tid"),"name", escapeDecode(StrList.getValues("tname")));
                                                        Topics.WriteString("topic"+StrList.GetValues("tid"),"description", escapeDecode(StrList.getValues("txt")));
//add keywords support:
                                                End;
Response.Redirect("./?f="+IntToStr(Fid)+"&t="+IntToStr(Tid)+"&p="+IntToStr(Pid)+"&lang="+lang+"&skin="+skin);
//                                              ShowTopics(Fid);
                                        end;
                                end
                                else Response.Writeln("Unknown TOPIC ID, post is was not saved!");
                                Topics.Free;
                        End
                        else begin
                                If (Tid==0) then begin
                                        Topics.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/topics.ini");
                                        Tid:=Topics.ReadInteger("global","count",0);
                                        If (Tid==0) then begin
                                                Tid:=1;
                                                //userscreate=true
                                        End
                                        Else Inc(Tid);
                                        Topics.WriteInteger("global","count",Tid);
                                        Topics.WriteInteger("topic"+IntToStr(Tid),"count",0);
                                        Topics.WriteString("topic"+IntToStr(Tid),"name",escapeDecode(StrList.getValues("tname")));
                                        Topics.WriteString("topic"+IntToStr(Tid),"description",escapeDecode(StrList.getValues("txt2")));
                                        Topics.WriteString("topic"+IntToStr(Tid),"creator",User);
                                        Topics.WriteInt64("topic"+IntToStr(Tid),"created",Timestamp);
                                        //keywords=Open Source, FOSS, Tiny, Forum, Free, Modern Pascal,About,Technical,Specifications
                                        //lastpost=f=1&t=1&p=2
                                        //lastposted=1446209471
                                        //lastposter=admin
                                        Topics.WriteInteger("topic"+IntToStr(Tid),"views",0);
                                        Topics.WriteInteger("topic"+IntToStr(Tid),"posts",0);
                                        Topics.Free;
                                        Topics.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/topics.ini");
                                        If (Pid==-1) then begin
                                                Sha:=Topics.ReadString("topic"+IntToStr(Tid),"sha256","");
                                                Txt:=EscapeDecode(escapeDecode(StrList.getValues("txt")));
                                                Sha2:=SHA256(Txt);
                                                If (Sha<>Sha2) then begin
                                                        NextMsg:=Topics.ReadInteger("topic"+IntToStr(Tid),"count",0)+1;
                                                        Topics.Free;
                                                        Topics.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/topics.ini");
                                                        Topics.WriteInteger("topic"+IntToStr(Tid),"count",NextMsg);
                                                        Topics.WriteString("topic"+IntToStr(Tid),"sha256",sha2);
                                                        Posts.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/"+IntToStr(Tid)+"/"+IntToStr(NextMsg)+".ini");
                                                        Posts.WriteString("header","name", Topics.ReadString("topic"+IntToStr(Tid),"name",""));
                                                        Posts.WriteInteger("header","count",0);
                                                        Posts.WriteInteger("header","views",0);
                                                        Posts.WriteInt64("header","posted",Timestamp);
                                                        Posts.WriteString("header","poster",User);
                                                        Posts.Free;
                                                        CompressPost("forums/"+StrList.getValues("fid")+"/"+IntToStr(Tid)+"/"+IntToStr(NextMsg),Txt);
                                                        Pid:=NextMsg;
                                                End;
                                        End;
                                        Forums.WriteInteger("forum"+IntToStr(Fid),"topics",1);
                                        Forums.WriteInt64("forum"+IntToStr(Fid),"lastposted",timestamp);
                                        Forums.WriteString("forum"+IntToStr(Fid),"lastposter",User);
                                        Forums.WriteString("forum"+IntToStr(Fid),"lastpost","f="+IntToStr(fid)+"&amp;t="+IntToStr(Tid)+"&amp;p="+IntToStr(pid));
                                        Topics.WriteInt64("topic"+IntToStr(Tid),"lastposted",timestamp);
                                        Topics.WriteString("topic"+IntToStr(Tid),"lastposter",User);
                                        Topics.WriteString("topic"+IntToStr(Tid),"lastpost","f="+IntToStr(fid)+"&amp;t="+IntToStr(Tid)+"&amp;p="+IntToStr(pid));
                                        Topics.Free;
Response.Redirect("./?f="+IntToStr(Fid)+"&t="+IntToStr(Tid)+"&p="+IntToStr(Pid)+"&lang="+lang+"&skin="+skin);
//                                      ShowPosts(Fid, Tid);
                                end
                                else If (Tid<0) then begin // Edit FORUMS.INI
                                        if (fid<>fid2) then begin
// rename folder to new ID (if not conflict, and change FORUMS# to new #
                                        End
                                        Else Begin
                                                Forums.WriteString("forum"+StrList.getValues("fid"),"name",escapeDecode(StrLIst.getValues("fname")));
                                                Forums.WriteString("forum"+StrList.getValues("fid"),"description",escapeDecode(StrLIst.getValues("txt")));
//add keywords support:
                                                Topics.Init(scriptroot+"forums/"+StrList.getValues("fid")+"/topics.ini");
                                        End;
Response.Redirect("./?f="+IntToStr(Fid)+"&t="+IntToStr(Tid)+"&p="+IntToStr(Pid)+"&lang="+lang+"&skin="+skin);
//                                      ShowForums();
                                End;
                        end;
                End
                else Response.Writeln("Unknown FORUM ID, post was not saved!");
        End
        else if (Fid==-1) then begin
                if (StrList.getValues("fname")!="") and (isAdmin) then begin
                        Fid:=Forums.ReadInteger("global","count",0);
                        Sha:=Forums.ReadString("global","sha256","");
                        Txt:=EscapeDecode(StrList.getValues("fname"));
                        Sha2:=SHA256(Txt);
                        if (Sha<>Sha2) then begin
                                Forums.WriteString("global","sha256",Sha2);
                                Inc(Fid);
                                Forums.WriteInteger("global","count",Fid);
                                Forums.WriteString("forum"+IntToStr(Fid),"name",Txt);
                                Forums.WriteString("forum"+IntToStr(Fid),"description",escapeDecode(StrList.getValues("txt")));
                                Forums.WriteString("forum"+IntToStr(Fid),"keywords",escapeDecode(StrList.getValues("fkwords")));
                                if (StrList.getValues("delete")=="on") then
                                        Forums.WriteBoolean("forum"+IntToStr(Fid),"usercreates",true)
                                else
                                        Forums.WriteBoolean("forum"+IntToStr(Fid),"usercreates",false);
                                Forums.WriteInteger("forum"+IntToStr(Fid),"topics",0);
                                Forums.WriteInt64("forum"+IntToStr(Fid),"created",Timestamp);
                                Forums.WriteString("forum"+IntToStr(Fid),"creator",User);
                                Forums.Free;
                                Forums.Init(scriptroot+"forums.ini");
                                CreateDirEx(scriptroot+"forums/"+IntToStr(Fid));
                        End;
Response.Redirect("./?f="+IntToStr(Fid)+"&t="+IntToStr(Tid)+"&p="+IntToStr(Pid)+"&lang="+lang+"&skin="+skin);
//                      ShowForums();
                End;
        end;
        Forums.Free;
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure Finalization();
var
        Cookie:TStringList;

begin
        Cookie:=Response.getSetCookie();
        If (User!="") then begin
                Sessions.Init(ScriptRoot+"sessions.ini");
                Sessions.WriteInt64(Kermit16(User,2112),"expires",TimeStamp+86400);
                Sessions.WriteString(Kermit16(User,2112),"user",User);
                Cookie.Add("TMPFSESSID="+Kermit16(USER,2112)+"&lang="+lang+"&skin="+skin+"&arc="+CRCARC(lang+skin+user,2112)+"; "+
                        "domain="+Request.getHost+"; "+
                        "path="+Copy(ScriptRoot,Length(Request.getDomainRoot)+1,255)+";");
                Sessions.Free;
        End
        Else Begin
                If CookieSession!="" then Cookie.Add("TMPFSESSID=; expires=Tue, 01 Jan 1980 11:00:00 GMT; "+
                        "domain="+Request.getHost+"; "+
                        "path="+Copy(ScriptRoot,Length(Request.getDomainRoot)+1,255)+";");
        End;
        StrList.Free;
        i18n.Free;
        if Config.ReadBoolean("global","hitcounter",true) then begin
                If (Config.ReadString("global","lastIP","")!=Request.GetPeerIP) then begin
                        Config.Free;
                        Config.Init(scriptroot+"config.ini");
                        Config.WriteInteger("global","hits", Config.ReadInteger("global","hits",1)+1);
                        Config.WriteString("global","lastIP",Request.GetPeerIP);
                end;
        end;
        Config.Free;
        Avatar.Free;
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure tryLogin;
var
        Users:TIniFile;
        Tmp:String;

begin
        StrList.SetDelimitedText(Request.GetPostData());
        Users.Init(ScriptRoot+"users.ini");
        Tmp:=Users.ReadString("global",lowercase(StrList.getValues("user")),"");
        If (Tmp!="") then begin
                If SHA256(StrList.getValues("passwd"))==Users.ReadString(Tmp,"password","Z") then begin
                        User:=StrList.getValues("user"); // save to cookie.
                        IsAdmin:=Users.ReadInteger(Tmp,"seclevel",0)==99;
                        lang:=Users.ReadString(Tmp,"lang",lang);
                        skin:=Users.ReadString(Tmp,"skin",skin);
                        Users.WriteInteger(Tmp, "logins", Users.ReadInteger(Tmp,"logins",0)+1);
                End
                Else Response.Writeln("<script>alert('Invalid credentials.');</script>");
// put them were they were - login or not!
                Forum:=StrToIntDef(StrList.getValues("fid"),Forum);
                Topic:=StrToIntDef(StrList.getValues("tid"),Topic);
                Post:=StrToIntDef(StrList.getValues("pid"),Post);
        End;
        Users.Free;
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure doProfile(CaptchaFailed:Boolean);
var
        Tmp,email,stat:String;
        AvID:Longint;

function buildLanguageList():String;
begin
        Result:="<td><select name='lang' style='width:120px'>";
        if lang=="en" then Result+="<option value='en' selected>English</option>"+CRLF
        else Result+="<option value='en'>English</option>"+CRLF;
        if lang=="de" then Result+="<option value='de' selected>Deutsch</option>"+CRLF
        else Result+="<option value='de'>Deutsch</option>"+CRLF;
        if lang=="es" then Result+="<option value='es' selected>Espa├▒ol</option>"+CRLF
        else Result+="<option value='es'>Espa├▒ol</option>"+CRLF;
        if lang=="fi" then Result+="<option value='fi' selected>Finnish</option>"+CRLF
        else Result+="<option value='fi'>Finnish</option>"+CRLF;
        if lang=="fr" then Result+="<option value='fr' selected>Fran├ºais</option>"+CRLF
        else Result+="<option value='fr'>Fran├ºais</option>"+CRLF;
        Result+="</select></td>"+CRLF;
end;

function buildSkinList():String;
begin
        Result:="<td><select name='skin' style='width:120px' autocomple='off'>";
        if skin=="blues" then Result+="<option value='blues' selected>TinyMPForum</option>"+CRLF
        else Result+="<option value='blues'>TinyMPForum</option>"+CRLF;
        if skin=="community" then Result+="<option value='community' selected>Community</option>"+CRLF
        else Result+="<option value='community'>Community</option>"+CRLF;
        if skin=="omega" then Result+="<option value='omega' selected>Omega Wars</option>"+CRLF
        else Result+="<option value='omega'>Omega Wars</option>"+CRLF;
        if skin=="ohyeah" then Result+="<option value='ohyeah' selected>XBox-ish</option>"+CRLF
        else Result+="<option value='ohyeah'>XBox-ish</option>"+CRLF;
        if skin=="tpf" then Result+="<option value='tpf' selected>TinyPHPForum</option>"+CRLF
        else Result+="<option value='tpf'>TinyPHPForum</option>"+CRLF;
        Result+="</select></td>"+CRLF;
end;

begin
        if (User!="") then begin
                Response.Writeln("<div class='barre'><a class='barreLien' href='./'>"+Config.ReadString("global","title",siteName)+
                        "</a> | "+i18n.getValues('l_profEditProf')+#32+User+"</div><div>");
                Response.Writeln("<form action='./?action=update' method='POST' onsubmit='return (checkRequired(["+
                        '&quot;uname&quot;,&quot;email&quot;'+"]) && checkChangePassword())'>"+CRLF+
                        "<input type='hidden' name='type' value='edit'>");
                Tmp:=avatar.ReadString("global", User, "guest");
                AvID:=avatar.ReadInteger(Tmp,"avatar",88);
                email:=avatar.ReadString(Tmp,"email","");
                stat:=avatar.ReadString(Tmp,"stat","");
                Tmp:="readonly";
        end
        else begin
                Response.Writeln("<div class='barre'><a class='barreLien' href='./'>"+Config.ReadString("global","title",siteName)+
                        "</a> | "+i18n.getValues('l_profNewAcc')+"</div><div>");
                Response.Writeln("<form action='./?action=update' method='POST' onsubmit='return checkRequired(["+
                        '&quot;uname&quot;,&quot;email&quot;,&quot;p1&quot;,&quot;p2&quot;'+"])'>"+CRLF+
                        "<input type='hidden' name='type' value='new'>");
                Tmp:="";
                AvID:=88;
                email:='';
                stat:='';
        end;
        Response.Writeln("<input type='hidden' name='fid' value='"+IntToStr(Forum)+"'>"+CRLF+
                "<input type='hidden' name='tid' value='"+IntToStr(Topic)+"'>"+CRLF+
                "<input type='hidden' name='pid' value='"+IntToStr(Post)+"'>");
        if (CaptchaFailed) then begin
                Response.Writeln("<div class='editionLight'><h3>Google reCaptcha Reported Failure</h3></div>");
        end;
        Response.Writeln("<table class='tablewide'><tr class='editionDark'>"+CRLF+
                "<td>"+i18n.getValues('l_profUsername')+"</td>"+CRLF+
                "<td>"+i18n.getValues('l_profLang')+"</td>"+CRLF+
                "<td>"+i18n.getValues('l_profSkin')+"</td>"+CRLF+
                "<td>"+i18n.getValues('l_profEmail')+"</td>"+CRLF+
                "<td>"+i18n.getValues('l_profEmailMsg')+"</td>"+CRLF+
                "</tr><tr>"+CRLF+
                "<td><input type='text' name='uname' id='uname' size='16' maxlength='12' value='"+User+"' "+Tmp+"></td>"+CRLF+
                buildLanguageList()+buildSkinList()+
                "<td colspan='2'><input type='text' name='email' id='email' size='40' maxlength='80' value='"+email+"'></td></tr>");
        If (User!="") then begin
                Response.Writeln("<tr class='editionDark'>"+
                        "<td>"+i18n.getValues('l_profPassOld')+"</td>"+CRLF+
                        "<td>"+i18n.getValues('l_profPassNew')+"</td>"+CRLF+
                        "<td>"+i18n.getValues('l_profPassConf')+"</td>"+CRLF+
                        "<td colspan='2'>"+i18n.getValues('l_profStatement2')+"</td>"+CRLF+
                        "</tr><tr>"+CRLF+
                        "<td><input type='password' name='opass' id='opass' size='16' maxlength='30' value=''></td>"+CRLF+
                        "<td><input type='password' name='p1' id='p1' size='16' maxlength='30' value=''></td>"+CRLF+
                        "<td><input type='password' name='p2' id='p2' size='16' maxlength='30' value=''></td>");
        End
        else Begin
                Response.Writeln("<tr class='editionDark'>"+
                        "<td>"+i18n.getValues('l_profPassNew')+"</td>"+CRLF+
                        "<td>"+i18n.getValues('l_profPassConf')+"</td>"+CRLF+
                        "<td></td>"+CRLF+
                        "<td colspan='2'>"+i18n.getValues('l_profStatement2')+"</td>"+CRLF+
                        "</tr><tr>"+CRLF+
                        "<td><input type='password' name='p1' id='p1' size='16' maxlength='30' value=''></td>"+CRLF+
                        "<td><input type='password' name='p2' id='p2' size='16' maxlength='30' value=''></td>"+CRLF+
                        "<td></td>");
        End;
        Response.Writeln("<td colspan='2'><input type='text' name='stat' size='40' maxlength='40' value='"+stat+"'></td></tr>");
        if (isAdmin) then begin
                Response.Writeln("<tr class='editionDark'><td>"+i18n.getValues('l_profAdmin')+"<input type='checkbox' name='makeadmin' checked='checked'></td>"+CRLF+
                        "<td colspan='4'>"+i18n.getValues('l_profDel')+"<input type='checkbox' name='delete'></td></tr>");
        end;
        Response.Writeln(
                "<tr class='editionDark'><td colspan='5'>"+i18n.getValues('l_profAvatar')+" "+
                "ID#: <input type='text' name='avID' id='avID' style='border:0px;background:transparent;font-size:12pt' value='"+
                IntToStr(avID)+"' readonly='readonly'></td></tr>"+CRLF+
                "<tr><td colspan='2'><div style='height:100px;'>"+CRLF+
                "<input type='button' value='&lt;' style='position:relative;left:0px;top:10px' onclick='prioravatar()'>"+CRLF+
                "<div id='avatarpicker'>"+showAvatar(AvID)+"</div>"+CRLF+
                "<input type='button' value='&gt;' style='position:relative;left:82px;top:-86px' onclick='nextavatar()'>"+CRLF+
                "</div></td>");
        if (User=="") then begin
                if (Config.ReadBoolean("global","userecaptcha",false)) then begin
                   Response.Writeln("<td colspan='3'><div class='g-recaptcha' data-sitekey='"+config.ReadString("recaptcha","sitekey","")+"'></div></td>");
                end;
        end;
        Response.Writeln("</tr>"+CRLF+"<tr class='editionDark'><td colspan='5'><input type='submit' value='OK'>"+
                " | <a class='link' href='./?f="+IntToStr(Forum)+"&amp;t="+IntToStr(topic)+"&amp;p="+IntToStr(post)+"'>Cancel</a>"+CRLF+
                "</td></tr>"+CRLF+
                "</table></form>");
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
procedure doUpdate;
var
        Users:TIniFile;
        Tmp,Ws:String;
        Ctr:Longint;
        GResponse:TStringList;

function BannedName(S:String):Boolean;
var
        BannedNames:TStringList;

begin
        BannedNames.Init();
        BannedNames.LoadFromFile(scriptroot+"bannednames.txt");
        Result:=Pos(#39,S)+Pos('"',S)+Pos(#32,S)>0;
        if not Result then for var loop=1 to bannedNames.getCount() do
                if Pos(#32+S+#32,#32+bannedNames.getStrings(Loop-1)+#32) then Result:=True;
        BannedNames.Free;
end;

begin
        StrList.SetDelimitedText(Request.GetPostData());
        If StrList.getValues("type")=="edit" then begin
                If (CookieCRC==CRCARC(Lang+Skin+StrList.getValues("uname"),2112)) then begin
                        if (lang<>StrList.getValues("lang")) or (skin<>StrList.getValues("skin")) then
                                Response.getSetCookie().Add("TMPFSESSID="+CookieSession+"&lang="+lang+"&skin="+skin+"&arc="+CookieCRC+"; "+
                                        "expires=Tue, 01 Jan 1980 11:00:00 GMT; "+
                                        "domain="+Request.getHost+"; "+
                                        "path="+Copy(ScriptRoot,Length(Request.getDomainRoot)+1,255)+";");
                        Users.Init(ScriptRoot+"users.ini");
                        Tmp:=Users.ReadString("global",lowercase(escapedecode(StrList.getValues("uname"))),"Guest");
                        Users.WriteString(Tmp,"avatar",StrList.getValues("avID"));
                        Users.WriteString(Tmp,"email",escapeDecode(StrList.getValues("email")));
                        Users.WriteString(Tmp,"stat",escapeDecode(StrList.getValues("stat")));
                        Users.WriteString(Tmp,"lang",escapeDecode(StrList.getValues("lang")));
                        Users.WriteString(Tmp,"skin",escapeDecode(StrList.getValues("skin")));
                        lang:=StrList.getValues("lang");
                        skin:=StrList.getValues("skin");
                        if (StrList.getValues("makeadmin")=="on") then Users.WriteInteger(Tmp,"seclevel",99)
                        else Users.WriteInteger(Tmp,"seclevel",0);
                        if (StrList.getValues("opass")!="") then begin
                                if (Users.ReadString(Tmp,"password","Z")==SHA256(StrList.getValues("opass"))) then begin
                                        if (StrList.getValues("p1")==StrList.getValues("p2")) then begin
                                                Users.WriteString(Tmp,"password",SHA256(StrList.getValues("p1")));
                                                Response.Writeln("<script>alert('Password change has been saved.');</script>");
                                        end;
                                end;
                        end;
                        Users.Free;
                        Forum:=StrToIntDef(StrList.getValues("fid"),0);
                        Topic:=StrToIntDef(StrList.getValues("tid"),0);
                        Post:=StrToIntDef(StrList.getValues("pid"),0);
                        Response.Redirect("./?f="+IntToStr(Forum)+"&t="+IntToStr(Topic)+"&p="+IntToStr(Post)+"&lang="+lang+"&skin="+skin+"&RL="+CookieSession);
                        User:='';
                        CookieSession:=''; // so Finalization does not send cookie too!
                        Exit;
                end;
        End
        Else If (Config.ReadBoolean("global", "allowNewuser", false)) then begin
                if (Config.ReadBoolean("global", "userecaptcha", false)) then begin
                        ws:="secret="+Config.ReadString("recaptcha","secretkey","")+"&response="+StrList.getValues("g-recaptcha-response");
{$IFDEF WINDOWS}

{$ELSE}
                        Tmp:="/tmp/"+Request.getPeerIP;
                        ExecuteEx("/usr/bin/curl",["--url","https://www.google.com/recaptcha/api/siteverify","-d",ws,"-o",Tmp]);
{$ENDIF}
                        gResponse.Init();
                        gResponse.LoadFromFile(Tmp);
                        DeleteFile(Tmp);
                        if Pos('"success": false',gResponse.getText())>0 then begin
                                showHTMLHeader(Forum);
                                doProfile(True);
                                gResponse.Free;
                                exit;
                        end;
                        gResponse.Free;
                end;
                Users.Init(ScriptRoot+"users.ini");
                Tmp:=lowercase(escapedecode(StrList.getValues("uname")));
                if (copy(tmp,1,1)='[') or (Users.ReadString("global",Tmp,"")!="") or BannedName(tmp) then begin
                        showHTMLHeader(Forum);
                        Response.Writeln("<div><div class='barre'><a class='barreLien' href='./'>"+Config.ReadString("global","title",siteName)+
                                "</a> | "+i18n.getValues('l_profNewAcc')+"</div>");
                        Response.Writeln("<h3 class='editionLight' style='font-size:18pt'>"+i18n.getValues('l_errUser')+"</h3>");
                        Response.Writeln("<form action='./?action=uadd' method='POST' onsubmit='return checkRequired(["+
                                '&quot;uname&quot;,&quot;email&quot;,&quot;p1&quot;,&quot;p2&quot;'+"])'>");
                        Response.Writeln("<input type='hidden' name='type' value='new'>");
                        Response.Writeln("<input type='hidden' name='p1' value='"+escapedecode(StrList.getValues("p1"))+"'>");
                        Response.Writeln("<input type='hidden' name='p2' value='"+escapedecode(StrList.getValues("p2"))+"'>");
                        Response.Writeln("<input type='hidden' name='avID' value='"+escapedecode(StrList.getValues("avID"))+"'>");
                        Response.Writeln("<input type='hidden' name='email' value='"+escapedecode(StrList.getValues("email"))+"'>");
                        Response.Writeln("<input type='hidden' name='stat' value='"+escapedecode(StrList.getValues("stat"))+"'>");
                        Response.Writeln("<input type='hidden' name='lang' value='"+escapedecode(StrList.getValues("lang"))+"'>");
                        Response.Writeln("<input type='hidden' name='skin' value='"+escapedecode(StrList.getValues("skin"))+"'>");
                        Response.Writeln("<div class='editionDark'>"+i18n.getValues('l_profUsername')+"</div>"+CRLF+
                                "<div class='editionLight'><input type='text' name='uname' id='uname' size='16' maxlength='12' value=''></div>"+CRLF+
                                "<div class='editionDark'><input type='submit' value='OK'>"+
                                " | <a class='link' href='./?f="+IntToStr(Forum)+"&amp;t="+IntToStr(topic)+"&amp;p="+IntToStr(post)+"'>Cancel</a>"+CRLF+
                                "</div></form>");
                        showFooter();
                        Response.Write("</table>"+CRLF+"</body></html>");
                end
                else begin
                        Ctr:=Users.ReadInteger("global", "count", 0)+1;
                        Users.WriteInteger("global", "count", Ctr);
                        Ws:="user"+IntToStr(Ctr);
                        Users.WriteString("global", Tmp, ws);
                        Users.WriteString(Ws, "userid", Tmp);
                        //Users.WriteString(Ws, "info", "");
                        Users.WriteString(Ws, "password", SHA256(escapeDecode(StrList.getValues("p1"))));
                        Users.WriteString(Ws, "email", lowercase(escapeDecode(StrList.getValues("email"))));
                        Users.WriteString(Ws, "lang", lowercase(escapeDecode(StrList.getValues("lang"))));
                        Users.WriteString(Ws, "avatar", escapeDecode(StrList.getValues("avID")));
                        Users.WriteString(Ws, "stat", escapeDecode(StrList.getValues("stat")));
                        Users.WriteString(Ws, "skin", escapeDecode(StrList.getValues("skin")));
                        Users.WriteInteger(Ws, "posts", 0);
                        Users.WriteInteger(Ws, "login", 0);
                        Users.WriteInteger(Ws, "seclevel", 0);
                        Response.Redirect("./?welcome");
                end;
                Users.Free;
                Exit;
        end;
        Response.Redirect("./?Potential_Hack_Attempt_Logged");
end;

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
Begin
        Initialization();
        if (action=="avatar") then Response.Write(showAvatar(StrToIntDef(StrList.getValues("avID"),88)))
        else if (action=="update") then doUpdate
        else begin
                showHTMLHeader(Forum);
                if Config.ReadBoolean("global","openForum",true) then begin
                        if (User!="Guest") then begin
                                if (action=="login") then tryLogin;
                                if (action=="logout") then begin
                                        if (User!="") then begin
                                                Sessions.Init(ScriptRoot+"sessions.ini");
                                                Sessions.EraseSection(CookieSession);
                                                Sessions.Free;
                                                User:='';
                                        end;
                                        Response.getSetCookie().Add("TMPFSESSID="+CookieSession+"&lang="+lang+"&skin="+skin+"&arc="+CookieCRC+"; "+
                                                "expires=Tue, 01 Jan 1980 11:00:00 GMT; "+
                                                "domain="+Request.getHost+"; "+
                                                "path="+Copy(ScriptRoot,Length(Request.getDomainRoot)+1,255)+";");
                                        Response.Redirect("./");
                                end
                                else if (action=="profile") then doProfile(false)
                                else if (action=="edit") then newPost(Forum, Topic, Post)
                                else if (action=="new") or
                                        (action=="epost") or
                                        (action=="eforum") or
                                        (action=="etopic") then savePost(Forum, Topic, Post)
                                else begin
                                        if (Forum>0) and (Topic>0) then showPosts(Forum, Topic)
                                        else if (Forum>0) then showTopics(Forum)
                                        else showForums();
                                end;
                        end
                        else Response.Write("<div class='barre'>Please Login</div><br>"+CRLF+
                                "<span class='quote'>You must login, or <a href='./action=profile'>register</a> to use this forum.</span>");
                end
                else begin
                        Response.Writeln("<div class='barre'>"+Config.ReadString("global","title","TMPF Forum")+"</div>"+CRLF+
                                "<h2 style='text-align:center'>This forum is closed.</h2>");
                end;
                if (action!="profile") then ShowMenu();
                showFooter();
                Response.Write("</table>"+CRLF+"</body></html>");
        end;
        Finalization();
        Response.setCacheControl("no-cache");
        Response.setExpires("Tue, 01 Jan 1980 1:00:00 GMT");
        Response.setPragma("no-cache");
        //Response.setLastModified("Tue, 01 Jan 1980 11:00:00 GMT");
end;
