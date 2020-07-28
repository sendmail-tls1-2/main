program sendmail;

{

<license.txt>

  fake sendmail for windows

  Copyright (c) 2004-2020, Byron Jones, sendmail@glob.com.au
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

    * Neither the name of the glob nor the names of its contributors may
      be used to endorse or promote products derived from this software
      without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

</license.txt>

<ChangeLog.txt>

  version 33 - Michel <sendmail@dotmol.nl> (27 july 2020)
    - Make the source compile in Embarcadero Delphi 10.3 with the default included Indy 10-260
    - Needs install of http://madshi.net/index.htm (madExcept 5.1.0) in Delphi Builder
    - Updated OpenSSL DLL's to 1.0.2u
    - Forced TLS v1.1 & v1.2, don't allow v1.0

  Byron Jones:
  version 32 - (18 june 2011)
    - fix handling of invalid recipients

  version 31 (15 sep, 2010)
    - fix encoding of 8-bit data

  version 30 (30 aug, 2010)
    - update to latest indy version (fixes many issues)
    - add about/version

  version 29 (sep 8, 2009)
    - fix for another indy 10 "range check error" (when using ssl)

  version 28 (aug 12, 2009)
    - set ERRORLEVEL to -1 to assist php

  version 27 (aug 3, 2009)
    - don't treat log write errors as fatal

  version 26 (apr 1, 2009)
    - no longer require -t parameter
    - skip first line if it starts with "from " (mail spool delimiting line)

  version 25 (mar 29, 2009)
    - added force_recipient

  version 24 (dec 2, 2008)
    - fixes for ssl

  version 23 (apr 24, 2008)
    - fix timezone in date header

  version 22 (jan 14, 2008)
    - fixes to error handling

  version 21 (jan 2, 2008)
    - added TLS support

  version 20 (apr 3, 2007)
    - fixed race condition in IIS's pickup delivery

  version 19 (jul 24, 2006)
    - added support for delivery via IIS's pickup directory
    - optionally reads settings from the registry (in absense of the ini file)

  version 18 (may 1, 2006)
    - fix for indy 10 "range check error"

  version 17 (nov 2, 2005)
    - only process message header
    - optionally use madexcept for detailed crash dumps

  version 16 (sep 12, 2005)
    - send hostname and domain with HELO/EHLO
    - configurable HELO/EHLO hostname
    - upgraded to indy 10

  version 15 (aug 23, 2005)
    - fixes error messages when debug_logfile is not specified

  version 14 (jun 28, 2005)
    - errors output to STDERR
    - fixes for delphi 7 compilation
    - added 'connecting to..' debug logging
    - reworked error and debug log format

  version 13 (jun 8, 2005)
    - added fix to work around invalid multiple header instances

  version 12 (apr 30, 2005)
    - added cc and bcc support

  version 11 (feb 17, 2005)
    - added pop3 support (for pop before smtp authentication)

  version 10 (feb 11, 2005)
    - added support for specifying a different smtp port

  version 9 (sep 22, 2004)
    - added force_sender

  version 8 (sep 22, 2004)
    - *really* fixes broken smtp auth

  version 7 (sep 22, 2004)
    - fixes broken smtp auth

  version 6 (sep 22, 2004)
    - correctly quotes MAIL FROM and RCPT TO addresses in &lt;&gt;

  version 5 (sep 16, 2004)
    - now sends the message unchanged (rather than getting indy
      to regenerate it)

  version 4 (aug 17, 2004)
    - added debug_logfile parameter
    - improved error messages

  version 3 (jul 15, 2004)
    - smtp authentication support
    - clearer error message when missing from or to address
    - optional error logging
    - adds date: if missing

  version 2 (jul 6, 2004)
    - reads default domain from registry (.ini setting overrides)

  version 1 (jul 1, 2004)
    - initial release

</ChangeLog.txt>

  requires indy 10.2 or higher
  i use a Tiburon branch svn pull
  https://svn.atozed.com:444/svn/Indy10/branches/Tiburon

  http://www.indyproject.org/Sockets/Docs/Indy10Installation.EN.aspx

}

{$APPTYPE CONSOLE}

//{$I IdCompilerDefines.inc}
//{$IFNDEF INDY100}indy version 10 is required; built against 10_5_6{$ENDIF}

{$DEFINE USE_MADEXCEPT}

uses
  Windows, Classes, SysUtils, Registry, IniFiles,
  IdGlobal, IdResourceStringsCore, IdGlobalProtocols, IdResourceStrings, IdExplicitTLSClientServerBase,
  IDSmtp, IDPOP3, IdMessage, IdEmailAddress, IdLogFile, IdWinSock2, IdIOHandler, IdSSLOpenSSL, IdException
  {$IFDEF USE_MADEXCEPT}
  , madExcept, madLinkDisAsm;
  {$ENDIF}
// ---------------------------------------------------------------------------

const
  VERSION = '33';

// ---------------------------------------------------------------------------

function buildLogLine(data, prefix: string) : string;
// ensure the output of error and debug logs are in the same format, regardless of source
begin

  data := StringReplace(data, EOL, RSLogEOL, [rfReplaceAll]);
  data := StringReplace(data, CR, RSLogCR, [rfReplaceAll]);
  data := StringReplace(data, LF, RSLogLF, [rfReplaceAll]);

  result := FormatDateTime('yy/mm/dd hh:nn:ss', now) + ' ';
  if (prefix <> '') then
    result := result + prefix + ' ';
  result := result + data + EOL;
end;

// ---------------------------------------------------------------------------

type

  // TidLogFile using buildLogLine function

  TlogFile = class(TidLogFile)
  protected
    procedure LogReceivedData(const AText, AData: string); override;
    procedure LogSentData(const AText, AData: string); override;
    procedure LogStatus(const AText: string); override;
  public
    procedure LogWriteString(const AText: string); override;
  end;

// ---------------------------------------------------------------------------

procedure TlogFile.LogReceivedData(const AText, AData: string);
begin
  // ignore AText as it contains the date/time
  LogWriteString(buildLogLine(Adata, '<<'));
end;

// ---------------------------------------------------------------------------

procedure TlogFile.LogSentData(const AText, AData: string);
begin
  // ignore AText as it contains the date/time
  LogWriteString(buildLogLine(Adata, '>>'));
end;

// ---------------------------------------------------------------------------

procedure TlogFile.LogStatus(const AText: string);
begin
  LogWriteString(buildLogLine(AText, '**'));
end;

// ---------------------------------------------------------------------------

procedure TlogFile.LogWriteString(const AText: string);
begin
  // protected --> public
  inherited;
end;

// ---------------------------------------------------------------------------

var
  errorLogFile: string;
  debugLogFile: string;
  debug       : TlogFile;

// ---------------------------------------------------------------------------

procedure writeToLog(const logFilename, logMessage: string; const prefix: string = '');
var
  f: TextFile;
begin
  AssignFile(f, logFilename);
  try

    if (not FileExists(logFilename)) then
    begin
      ForceDirectories(ExtractFilePath(logFilename));
      Rewrite(f);
    end
    else
      Append(f);

    write(f, buildLogLine(logMessage, prefix));
    closeFile(f);

  except
    on e:Exception do
      writeln(ErrOutput, 'sendmail: Error writing to ' + logFilename + ': ' + logMessage);
  end;
end;

// ---------------------------------------------------------------------------

procedure debugLog(const logMessage: string);
begin
  if (debug <> nil) and (debug.Active) then
    debug.LogWriteString(buildLogLine(logMessage, '**'))
  else if (debugLogFile <> '') then
    writeToLog(debugLogFile, logMessage, '**');
end;

// ---------------------------------------------------------------------------

procedure errorLog(const logMessage: string);
begin
  if (errorLogFile <> '') then
    writeToLog(errorLogFile, logMessage, ':');
  debugLog(logMessage);
end;

// ---------------------------------------------------------------------------

function appendDomain(const address, domain: string): string;
begin
  Result := address;
  if (Pos('@', address) <> 0) then
    Exit;
  Result := Result + '@' + domain;
end;

// ---------------------------------------------------------------------------

function joinMultiple(const messageContent: string; fieldName: string): string;
// the rfc says that some fields are only allowed once in a message header
// for example, to, from, subject
// this function joins multiple instances of the specified field into a single comma seperated line
var
  sl    : TstringList;
  i     : integer;
  s     : string;
  n     : integer;
  count : integer;
  values: TstringList;
begin

  fieldName := LowerCase(fieldName);
  sl := TStringList.Create;
  values := TStringList.Create;
  try

    sl.text := messageContent;
    result := '';

    // only modify the header if there's more than one instance of the field

    count := 0;
    for i := 0 to sl.count - 1 do
    begin
      s := sl[i];
      if (s = '') then
        break;
      n := pos(':', s);
      if (n = 0) then
        break;
      if (lowerCase(copy(s, 1, n - 1)) = fieldName) then
        inc(count);
    end;

    if (count <= 1) then
    begin
      result := messageContent;
      exit;
    end;

    // more than on instance of the field, combine into single entry, ignore fields with empty values

    while (sl.count > 0) do
    begin
      s := sl[0];
      if (s = '') then
        break;
      n := pos(':', s);
      if (n = 0) then
        break;

      if (lowerCase(copy(s, 1, n - 1)) = fieldName) then
      begin
        s := trim(copy(s, n + 1, length(s)));
        if (s <> '') then
          values.Add(s);
      end
      else
        result := result + s + #13#10;

      sl.Delete(0);
    end;

    if (values.count <> 0) then
    begin
      s := UpCaseFirst(fieldName) + ': ';
      for i := 0 to values.count - 1 do
        s := s + values[i] + ', ';
      setLength(s, length(s) - 2);
      result := result + s + #13#10;
    end;

    result := result + sl.Text;

  finally
    values.Free;
    sl.free;
  end;

end;

// ---------------------------------------------------------------------------

function DateTimeToInternetStr(const Value: TDateTime): string;
var
  day  : word;
  month: word;
  year : word;
begin
  DecodeDate(Value, year, month, day);
  Result := Format(
    '%s, %d %s %d %s %s',
    [
      wdays[DayOfWeek(Value)],
      day,
      monthnames[month],
      year,
      FormatDateTime('HH":"mm":"ss', Value),
      UTCOffsetToStr(OffsetFromUTC, false)
    ]
  );
end;

// ---------------------------------------------------------------------------

{$IFDEF USE_MADEXCEPT}
procedure madExceptionHandler(const exceptIntf: IMEException; var handled: boolean);
var
  path: string;
  i   : integer;
  fs  : TFileStream;
  s   : string;
begin
  handled := true;

  path := extractFilePath(debugLogFile);

  deleteFile(path + 'crash-5.txt');
  for i := 4 downto 1 do
  if (fileExists(path + 'crash-' + intToStr(i) + '.txt')) then
    RenameFile(path + 'crash-'+ intToStr(i) + '.txt', path + 'crash-' + intToStr(i + 1) + '.txt');
  if (fileExists(path + 'crash.txt')) then
    RenameFile(path + 'crash.txt', path + 'crash-1.txt');

  fs := TFileStream.Create(path + 'crash.txt', fmCreate);
  try
    s := exceptIntf.GetBugReport;
    fs.Write(s[1], length(s));
  finally
    fs.free;
  end;

  ExitProcess(DWORD(-1));
end;
{$ENDIF}

// ---------------------------------------------------------------------------

var

  smtpServer    : string;
  smtpPort      : string;
  smtpSSL       : (ssAuto, ssSSL, ssTLS, ssNone);
  defaultDomain : string;
  messageContent: string;
  authUsername  : string;
  authPassword  : string;
  forceSender   : string;
  forceRcpt     : string;
  pop3server    : string;
  pop3username  : string;
  pop3password  : string;
  hostname      : string;
  isPickup      : boolean;

  reg : TRegistry;
  ini : TCustomIniFile;
  pop3: TIdPop3;
  smtp: TIdSmtp;

  i     : integer;
  s     : string;
  ss    : TStringStream;
  msg   : TIdMessage;
  sl    : TStringList;
  header: boolean;
  fs    : TFileStream;

  validRecipientCount: integer;

begin

  // command line help

  if (ParamStr(1) = '-h') then
  begin
    writeln('fake sendmail version ' + VERSION);
    writeln('http://glob.com.au/sendmail');
    halt(1);
  end;

  // read default domain from registry

  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if (reg.OpenKeyReadOnly('\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters')) then
      defaultDomain := reg.ReadString('Domain');
  finally
    reg.Free;
  end;

  // read ini

  s := ChangeFileExt(ParamStr(0), '.ini');
  if (FileExists(s)) then
    ini := TIniFile.Create(s)
  else
  begin
    ini := TRegistryIniFile.Create('\software');
    TRegistryIniFile(ini).RegIniFile.RootKey := HKEY_LOCAL_MACHINE;
    TRegistryIniFile(ini).RegIniFile.OpenKey(TRegistryIniFile(ini).FileName, true);
  end;

  try

    smtpServer    := ini.ReadString('sendmail', 'smtp_server',     'mail.mydomain.com');
    smtpPort      := ini.ReadString('sendmail', 'smtp_port',       '25');
    defaultDomain := ini.ReadString('sendmail', 'default_domain',  defaultDomain);
    hostname      := ini.ReadString('sendmail', 'hostname',        '');
    errorLogFile  := ini.ReadString('sendmail', 'error_logfile',   '');
    debugLogFile  := ini.ReadString('sendmail', 'debug_logfile',   '');
    authUsername  := ini.ReadString('sendmail', 'auth_username',   '');
    authPassword  := ini.ReadString('sendmail', 'auth_password',   '');
    forceSender   := ini.ReadString('sendmail', 'force_sender',    '');
    forceRcpt     := ini.ReadString('sendmail', 'force_recipient', '');
    pop3server    := ini.ReadString('sendmail', 'pop3_server',     '');
    pop3username  := ini.ReadString('sendmail', 'pop3_username',   '');
    pop3password  := ini.ReadString('sendmail', 'pop3_password',   '');

    s := LowerCase(ini.ReadString('sendmail', 'smtp_ssl', 'auto'));
    if (s = 'ssl') then
      smtpSSL := ssSSL
    else if (s = 'tls') then
      smtpSSL := ssTLS
    else if (s = 'none') then
      smtpSSL := ssNone
    else
      smtpSSL := ssAuto;

    if (smtpServer = 'mail.mydomain.com') or (defaultDomain = 'mydomain.com') then
    begin
      writeln(ErrOutput, 'You must configure the smtp_server and default_domain in:');
      writeln(ErrOutput, '  ' + ini.fileName);
      writeln(ErrOutput, '  or');
      writeln(ErrOutput, '  HKLM\Software\Sendmail');
      ExitProcess(DWORD(-1));
    end;

  finally
    ini.Free;
  end;

  if (errorLogFile <> '') and (ExtractFilePath(errorLogFile) = '') then
    errorLogFile := ExtractFilePath(ParamStr(0)) + errorLogFile;

  if (debugLogFile <> '') and (ExtractFilePath(debugLogFile) = '') then
    debugLogFile := ExtractFilePath(ParamStr(0)) + debugLogFile;

  isPickup := DirectoryExists(smtpServer);
  if (isPickup) then
    smtpServer := IncludeTrailingPathDelimiter(smtpServer);

  s := ParamStr(1);
  if (s <> '') and (s[1] <> '-') and (FileExists(s)) then
  begin

    // read email from file

    fs := TFileStream.Create(ParamStr(1), fmOpenRead + fmShareDenyWrite);
    try
      setLength(messageContent, fs.Size);
      fs.Read(messageContent[1], length(messageContent));
    finally
      fs.Free;
    end;

  end
  else
  begin

    // read email from stdin

    messageContent := '';
    while (not eof(Input)) do
    begin
      readln(Input, s);
      if (messageContent = '') and (copy(s, 1, 5) = 'From ') then
        continue;
      messageContent := messageContent + s + #13#10;
    end;

  end;

  // make sure message is CRLF delimited

  if (pos(#10, messageContent) = 0) then
    messageContent := stringReplace(messageContent, #13, #13#10, [rfReplaceAll]);

  if (debugLogFile <> '') then
  begin
    debugLog('--- MESSAGE BEGIN ---');
    sl := TStringList.Create;
    try
      sl.Text := messageContent;
      for i := 0 to sl.Count - 1 do
        debugLog(sl[i]);
    finally
      sl.Free;
    end;
    debugLog('--- MESSAGE END ---');
  end;

  // fix multiple to, cc, bcc and subject fields

  messageContent := joinMultiple(messageContent, 'to');
  messageContent := joinMultiple(messageContent, 'cc');
  messageContent := joinMultiple(messageContent, 'bcc');
  messageContent := joinMultiple(messageContent, 'subject');

  // deliver message

  {$IFDEF USE_MADEXCEPT}
  RegisterExceptionHandler(madExceptionHandler, stTrySyncCallAlways);
  {$ENDIF}

  try

    if (isPickup) then
    begin

      // drop to IIS's pickup directory

      ForceDirectories(smtpServer + 'Temp');

      // generate filename (in the temp directory)

      setLength(s, MAX_PATH);
      if (GetTempFileName(pChar(smtpServer + 'Temp'), 'sm', 0, @s[1]) = 0) then
        RaiseLastOSError;
      s := strPas(pChar(s));

      // write

      fs := TFileStream.Create(s, fmCreate);
      try
        fs.Write(messageContent[1], length(messageContent));
      finally
        fs.free;
      end;

      // move into the real pickup directory

      if (not RenameFile(s, smtpServer + ChangeFileExt(ExtractFileName(s), '.eml'))) then
        RaiseLastOSError;

      RemoveDir(smtpServer + 'Temp');

    end
    else
    begin

      // deliver via smtp

      // load message into stream

      ss  := TStringStream.Create(messageContent);
      msg := nil;

      try

        // load message

        msg := TIdMessage.Create(nil);
        try
          msg.LoadFromStream(ss, true);
        except
          on e:exception do
            raise exception.create('Failed to read email message: ' + e.message);
        end;

        // check for from and to

        if (forceSender = '') and (Msg.From.Address = '') then
          raise Exception.Create('Message is missing sender''s address');
        if (forceRcpt = '') and (Msg.Recipients.Count = 0) and (Msg.CCList.Count = 0) and (Msg.BccList.Count = 0) then
          raise Exception.Create('Message is missing recipient''s address');

        if (debugLogFile <> '') then
        begin
          try
            debug          := TlogFile.Create(nil);
            debug.FileName := debugLogFile;
            debug.Active   := True;
          except
            // silently ignore
            debug := nil;
          end;
        end
        else
          debug := nil;

        if ((pop3server <> '') and (pop3username <> '')) then
        begin

          // pop3 before smtp auth

          debugLog('Authenticating with POP3 server');

          pop3 := TIdPOP3.Create(nil);
          try
            if (debug <> nil) then
            begin
              pop3.IOHandler           := TIdIOHandler.MakeDefaultIOHandler(pop3);
              pop3.IOHandler.Intercept := debug;
              pop3.IOHandler.OnStatus  := pop3.OnStatus;
              pop3.ManagedIOHandler    := True;
            end;
            pop3.Host           := pop3server;
            pop3.Username       := pop3username;
            pop3.Password       := pop3password;
            pop3.ConnectTimeout := 10 * 1000;
            pop3.Connect;
            pop3.Disconnect;
          finally
            pop3.free;
          end;

        end;

        smtp := TIdSMTP.Create(nil);
        try

          // if openSSL libraries are available, use SSL for TLS support

          smtp.IOHandler := nil;
          smtp.ManagedIOHandler := True;

          if (smtpSSL <> ssNone) then
          begin
            try
              TIdSSLContext.Create.Free;
              smtp.IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create(smtp);
              //smtp.IOHandler.SSLOptions.Method := sslvTLSv1_2;

              TIdSSLIOHandlerSocketOpenSSL(smtp.IOHandler).SSLOptions.SSLVersions := [sslvTLSv1_1, sslvTLSv1_2];

              if (smtpSSL = ssAuto) then
                if (strToIntDef(smtpPort, 25) = 465) then
                  smtpSSL := ssSSL
                else
                  smtpSSL := ssTLS;

              if (smtpSSL = ssSSL) then
                smtp.UseTLS := utUseImplicitTLS
              else
                smtp.UseTLS := utUseExplicitTLS;
            except
              on e:exception do
              begin
                debugLog('Failed to load SSL libraries: ' + e.message);
                smtp.IOHandler := nil;
              end;
            end;
          end;

          if (smtp.IOHandler = nil) then
          begin
            smtp.IOHandler := TIdIOHandler.MakeDefaultIOHandler(smtp);
            smtp.UseTLS := utNoTLSSupport;
          end;

          if (debug <> nil) then
          begin
            smtp.IOHandler.Intercept := debug;
            smtp.IOHandler.OnStatus  := smtp.OnStatus;
          end;

          // set host, port

          i := pos(':', smtpServer);
          if (i = 0) then
          begin
            smtp.host := smtpServer;
            smtp.port := strToIntDef(smtpPort, 25);
          end
          else
          begin
            smtp.host := copy(smtpServer, 1, i - 1);
            smtp.port := strToIntDef(copy(smtpServer, i + 1, length(smtpServer)), 25);
          end;

          // set hostname (for helo/ehlo)

          if (hostname = '') then
          begin
            setLength(hostname, 255);
            GetHostName(PAnsiChar(hostname), length(hostname));
            hostname := string(PAnsiChar(hostname));
            if (pos('.', hostname) = 0) and (defaultDomain <> '') then
              hostname := hostname + '.' + defaultDomain;
          end;
          smtp.HeloName := hostname;

          // connect to server

          debugLog('Connecting to ' + smtp.Host + ':' + intToStr(smtp.Port));

          smtp.ConnectTimeout := 10 * 1000;
          smtp.Connect;

          // set up authentication

          if (authUsername <> '') then
          begin
            debugLog('Authenticating as ' + authUsername);
            smtp.AuthType := satDefault;
            smtp.Username := authUsername;
            smtp.Password := authPassword;
          end;

          // authenticate and start tls

          smtp.Authenticate;

          // sender and recipients

          validRecipientCount := 0;
          
          if (forceSender = '') then
            smtp.SendCmd('MAIL FROM: <' + appendDomain(Msg.From.Address, defaultDomain) + '>', [250])
          else
            smtp.SendCmd('MAIL FROM: <' + appendDomain(forceSender, defaultDomain) + '>', [250]);

          if (forceRcpt = '') then
          begin
            for i := 0 to msg.Recipients.Count - 1 do
              if (smtp.SendCmd('RCPT TO: <' + appendDomain(Msg.Recipients[i].Address, defaultDomain) + '>', [250, 550]) = 250) then
                inc(validRecipientCount)
              else
                errorLog('Invalid recipient <' + appendDomain(Msg.Recipients[i].Address, defaultDomain) + '>');

            for i := 0 to msg.ccList.Count - 1 do
              if (smtp.SendCmd('RCPT TO: <' + appendDomain(Msg.ccList[i].Address, defaultDomain) + '>', [250, 550]) = 250) then
                inc(validRecipientCount)
              else
                errorLog('Invalid recipient <' + appendDomain(Msg.ccList[i].Address, defaultDomain) + '>');

            for i := 0 to msg.BccList.Count - 1 do
              if (smtp.SendCmd('RCPT TO: <' + appendDomain(Msg.BccList[i].Address, defaultDomain) + '>', [250, 550]) = 250) then
                inc(validRecipientCount)
              else
                errorLog('Invalid recipient <' + appendDomain(Msg.BccList[i].Address, defaultDomain) + '>');
          end
          else
            if (smtp.SendCmd('RCPT TO: <' + appendDomain(forceRcpt, defaultDomain) + '>', [250, 550]) = 250) then
              inc(validRecipientCount)
            else
              errorLog('Invalid recipient <' + appendDomain(forceRcpt, defaultDomain) + '>');

          if (validRecipientCount = 0) then
            raise Exception.Create('No valid recipients were found');

          // start message content

          smtp.SendCmd('DATA', [354]);

          // add date header if missing

          if (Msg.Headers.Values['date'] = '') then
            smtp.IOHandler.WriteLn('Date: ' + DateTimeToInternetStr(Now));

          // send message line by line

          sl := TStringList.Create;
          try
            sl.Text := messageContent;
            header  := true;
            for i := 0 to sl.Count - 1 do
            begin
              if (i = 0) and (sl[i] = '') then
                continue;
              if (sl[i] = '') then
                header := false;
              if (header) and (LowerCase(copy(sl[i], 1, 5)) = 'bcc: ') then
                continue;
              smtp.IOHandler.WriteLn(sl[i], IndyTextEncoding_OSDefault());
            end;
          finally
            sl.Free;
          end;

          // done

          smtp.SendCmd('.', [250]);
          try
            smtp.SendCmd('QUIT');
          except
            on e:EIdConnClosedGracefully do
              ;// ignore
            on e:Exception do
              raise;
          end;

        finally

          if (smtp.Connected) then
            debugLog('Disconnecting from ' + smtp.Host + ':' + intToStr(smtp.Port));

          smtp.Free;
        end;

      finally
        msg.Free;
        ss.Free;
      end;

    end;

  except
    on e:Exception do
    begin
      writeln(ErrOutput, 'sendmail: Error during delivery: ' + e.message);
      errorLog(e.Message);
      {$IFDEF USE_MADEXCEPT}
      raise;
      {$ELSE}
      ExitProcess(DWORD(-1));
      {$ENDIF}
    end;
  end;

end.

