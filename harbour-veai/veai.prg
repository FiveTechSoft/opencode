/*
 * veai.prg - Harbour AI Client for OpenCode Zen
 *
 * A command-line AI client written in Harbour that connects to the
 * OpenCode Zen API (OpenAI-compatible). Supports single-shot queries,
 * interactive chat, streaming output, system prompts, and multiple
 * free models.
 *
 * Build:
 *   hbmk2 veai.hbp
 *
 * Usage:
 *   veai.exe "What is Harbour?"
 *   veai.exe --chat
 *   veai.exe --chat --system "You are a Harbour expert"
 *   veai.exe --stream "Explain OOP in 3 sentences"
 *   veai.exe --model deepseek-v4-flash-free "Hello"
 *   veai.exe --temp 0.3 "Write a poem"
 *   veai.exe --list
 *   veai.exe --help
 *
 * Chat Commands (interactive mode):
 *   /help              Show available commands
 *   /exit, /quit, /q   Exit chat
 *   /clear             Clear conversation history
 *   /model <name>      Change model
 *   /temp <value>      Change temperature (0.0-2.0)
 *   /system <text>     Set/change system prompt
 *   /history           Show conversation history
 *   /models            List available models
 */


#include "hbcurl.ch"



// ============================================================
// API Configuration
// ============================================================
#define API_URL          "https://opencode.ai/zen/v1/chat/completions"
#define API_KEY          "public"
#define DEFAULT_MODEL    "mimo-v2.5-free"
#define DEFAULT_TEMP     0.7
#define MAX_TOKENS       4096
#define CURL_TIMEOUT     120

// ============================================================
// Entry Point
// ============================================================
FUNCTION Main( ... )

   LOCAL aArgs := hb_aParams()
   LOCAL hOpts

   IF Len( aArgs ) == 0
      showHelp()
      RETURN NIL
   ENDIF

   hOpts := parseArgs( aArgs )

   DO CASE
   CASE hOpts[ "help" ]
      showHelp()
   CASE hOpts[ "list" ]
      showModels()
   CASE hOpts[ "chat" ]
      runChat( hOpts )
   OTHERWISE
      runOnce( hOpts )
   ENDCASE

   RETURN NIL

// ============================================================
// Argument Parser
// ============================================================
STATIC FUNCTION parseArgs( aArgs )

   LOCAL hOpts := hb_Hash()
   LOCAL n := 1
   LOCAL cArg

   hOpts[ "help"   ] := .F.
   hOpts[ "list"   ] := .F.
   hOpts[ "chat"   ] := .F.
   hOpts[ "stream" ] := .F.
   hOpts[ "model"  ] := DEFAULT_MODEL
   hOpts[ "system" ] := ""
   hOpts[ "temp"   ] := DEFAULT_TEMP
   hOpts[ "prompt" ] := ""

   DO WHILE n <= Len( aArgs )
      cArg := aArgs[ n ]

      DO CASE
      CASE cArg == "-h" .OR. cArg == "--help"
         hOpts[ "help" ] := .T.

      CASE cArg == "-l" .OR. cArg == "--list"
         hOpts[ "list" ] := .T.

      CASE cArg == "-c" .OR. cArg == "--chat"
         hOpts[ "chat" ] := .T.

      CASE cArg == "-s" .OR. cArg == "--stream"
         hOpts[ "stream" ] := .T.

      CASE cArg == "-m" .OR. cArg == "--model"
         n++
         IF n <= Len( aArgs )
            hOpts[ "model" ] := aArgs[ n ]
         ENDIF

      CASE cArg == "--system"
         n++
         IF n <= Len( aArgs )
            hOpts[ "system" ] := aArgs[ n ]
         ENDIF

      CASE cArg == "--temp"
         n++
         IF n <= Len( aArgs )
            hOpts[ "temp" ] := Val( aArgs[ n ] )
         ENDIF

      OTHERWISE
         IF ! Empty( hOpts[ "prompt" ] )
            hOpts[ "prompt" ] += " "
         ENDIF
         hOpts[ "prompt" ] += cArg
      ENDCASE

      n++
   ENDDO

   IF Empty( hOpts[ "prompt" ] ) .AND. ! hOpts[ "chat" ]
      hOpts[ "prompt" ] := "Explain what is Harbour programming language in 3 sentences"
   ENDIF

   RETURN hOpts

// ============================================================
// Single-Shot Mode
// ============================================================
STATIC PROCEDURE runOnce( hOpts )

   LOCAL cJson
   LOCAL cResponse
   LOCAL hState

   cJson := buildSingleRequest( hOpts )

   ? "OpenCode Zen - Harbour AI Client"
   ? "================================"
   ? ""
   ? "Model:  " + hOpts[ "model" ]
   ? "Prompt: " + hOpts[ "prompt" ]
   IF ! Empty( hOpts[ "system" ] )
      ? "System: " + hOpts[ "system" ]
   ENDIF
   ? "Stream: " + IIF( hOpts[ "stream" ], "Yes", "No" )
   ? ""

   IF hOpts[ "stream" ]
      ?? "Response: "
      cResponse := ""
      hState := initStreamState()
      callAPIStream( cJson, @cResponse, hState )
      ? ""
   ELSE
      cResponse := callAPI( cJson )
      displayResponse( cResponse )
   ENDIF

   ? ""

   RETURN

// ============================================================
// Interactive Chat Mode
// ============================================================
STATIC PROCEDURE runChat( hOpts )

   LOCAL aHistory := {}
   LOCAL cInput
   LOCAL cJson
   LOCAL cResponse
   LOCAL hState

   IF ! Empty( hOpts[ "system" ] )
      addMessage( aHistory, "system", hOpts[ "system" ] )
   ENDIF

   ? "OpenCode Zen - Interactive Chat"
   ? "================================"
   ? "Model: " + hOpts[ "model" ]
   ? "Commands: /help /exit /clear /model <name> /temp <value>"
   ? ""

   DO WHILE .T.
      ACCEPT "You: " TO cInput
      cInput := Trim( cInput )

      IF Empty( cInput )
         LOOP
      ENDIF

      IF Left( cInput, 1 ) == "/"
         IF ! handleCommand( cInput, hOpts, aHistory )
            EXIT
         ENDIF
         LOOP
      ENDIF

      addMessage( aHistory, "user", cInput )
      cJson := buildChatRequest( hOpts, aHistory )

      ?? "AI:  "
      cResponse := ""
      hState := initStreamState()
      callAPIStream( cJson, @cResponse, hState )
      ? ""

      IF ! Empty( cResponse )
         addMessage( aHistory, "assistant", cResponse )
      ENDIF
   ENDDO

   ? ""
   ? "Chat ended."

   RETURN

// ============================================================
// Stream State
// ============================================================
STATIC FUNCTION initStreamState()

   LOCAL hState := hb_Hash()
   hState[ "buffer"   ] := ""
   hState[ "response" ] := ""
   hState[ "done"     ] := .F.

   RETURN hState

// ============================================================
// Add Message to History
// ============================================================
STATIC PROCEDURE addMessage( aHistory, cRole, cContent )

   LOCAL hMsg := hb_Hash()
   hMsg[ "role"    ] := cRole
   hMsg[ "content" ] := cContent
   AAdd( aHistory, hMsg )

   RETURN

// ============================================================
// Build Request (Single-Shot)
// ============================================================
STATIC FUNCTION buildSingleRequest( hOpts )

   LOCAL aMessages := {}
   LOCAL hBody

   IF ! Empty( hOpts[ "system" ] )
      addMessage( aMessages, "system", hOpts[ "system" ] )
   ENDIF

   addMessage( aMessages, "user", hOpts[ "prompt" ] )

   hBody := hb_Hash()
   hBody[ "model"       ] := hOpts[ "model" ]
   hBody[ "messages"    ] := aMessages
   hBody[ "temperature" ] := hOpts[ "temp" ]
   hBody[ "max_tokens"  ] := MAX_TOKENS

   IF hOpts[ "stream" ]
      hBody[ "stream" ] := .T.
   ENDIF

   RETURN hb_jsonEncode( hBody )

// ============================================================
// Build Request (Chat with History)
// ============================================================
STATIC FUNCTION buildChatRequest( hOpts, aHistory )

   LOCAL hBody := hb_Hash()
   hBody[ "model"       ] := hOpts[ "model" ]
   hBody[ "messages"    ] := aHistory
   hBody[ "temperature" ] := hOpts[ "temp" ]
   hBody[ "max_tokens"  ] := MAX_TOKENS
   hBody[ "stream"      ] := .T.

   RETURN hb_jsonEncode( hBody )

// ============================================================
// API Call (Non-Streaming)
// ============================================================
STATIC FUNCTION callAPI( cJson )

   LOCAL hCurl := curl_easy_init()
   LOCAL cResponse := ""
   LOCAL nResult

   IF hCurl == NIL
      RETURN "Error: Could not initialize libcurl"
   ENDIF

   curl_easy_setopt( hCurl, HB_CURLOPT_URL, API_URL )
   curl_easy_setopt( hCurl, HB_CURLOPT_POST, .T. )
   curl_easy_setopt( hCurl, HB_CURLOPT_POSTFIELDS, cJson )
   curl_easy_setopt( hCurl, HB_CURLOPT_HTTPHEADER, { ;
      "Content-Type: application/json", ;
      "Authorization: Bearer " + API_KEY ;
   } )
   curl_easy_setopt( hCurl, HB_CURLOPT_WRITEFUNCTION, {|cData| cResponse += cData } )
   curl_easy_setopt( hCurl, HB_CURLOPT_TIMEOUT, CURL_TIMEOUT )
   curl_easy_setopt( hCurl, HB_CURLOPT_CAINFO, "C:/curl64/bin/curl-ca-bundle.crt" )
   curl_easy_setopt( hCurl, HB_CURLOPT_SSL_VERIFYPEER, .T. )


   nResult := curl_easy_perform( hCurl )
   curl_easy_cleanup( hCurl )

   IF nResult != HB_CURLE_OK
      RETURN "Error: " + curl_easy_strerror( nResult )
   ENDIF

   RETURN cResponse

// ============================================================
// API Call (Streaming)
// ============================================================
STATIC PROCEDURE callAPIStream( cJson, cFullResponse, hState )

   LOCAL hCurl := curl_easy_init()
   LOCAL nResult

   IF hCurl == NIL
      ? ""
      ? "Error: Could not initialize libcurl"
      RETURN
   ENDIF

   curl_easy_setopt( hCurl, HB_CURLOPT_URL, API_URL )
   curl_easy_setopt( hCurl, HB_CURLOPT_POST, .T. )
   curl_easy_setopt( hCurl, HB_CURLOPT_POSTFIELDS, cJson )
   curl_easy_setopt( hCurl, HB_CURLOPT_HTTPHEADER, { ;
      "Content-Type: application/json", ;
      "Authorization: Bearer " + API_KEY ;
   } )
   curl_easy_setopt( hCurl, HB_CURLOPT_TIMEOUT, CURL_TIMEOUT )
   curl_easy_setopt( hCurl, HB_CURLOPT_CAINFO, "C:/curl64/bin/curl-ca-bundle.crt" )
   curl_easy_setopt( hCurl, HB_CURLOPT_SSL_VERIFYPEER, .T. )

   curl_easy_setopt( hCurl, HB_CURLOPT_WRITEFUNCTION, ;
      {|cData| processChunk( cData, hState ), Len( cData ) } )

   nResult := curl_easy_perform( hCurl )
   curl_easy_cleanup( hCurl )

   IF nResult != HB_CURLE_OK
      ? ""
      ? "Error: " + curl_easy_strerror( nResult )
   ENDIF

   cFullResponse := hState[ "response" ]

   RETURN

// ============================================================
// Process Streaming SSE Chunk
// ============================================================
STATIC PROCEDURE processChunk( cData, hState )

   LOCAL cBuffer
   LOCAL cLine
   LOCAL nPos
   LOCAL cJson
   LOCAL hJson
   LOCAL cContent

   IF hState[ "done" ]
      RETURN
   ENDIF

   cBuffer := hState[ "buffer" ] + cData

   DO WHILE .T.
      nPos := At( Chr(13) + Chr(10), cBuffer )
      IF nPos == 0
         nPos := At( Chr(10), cBuffer )
      ENDIF

      IF nPos == 0
         hState[ "buffer" ] := cBuffer
         RETURN
      ENDIF

      cLine := Left( cBuffer, nPos - 1 )
      IF SubStr( cBuffer, nPos, 2 ) == Chr(13) + Chr(10)
         cBuffer := SubStr( cBuffer, nPos + 2 )
      ELSE
         cBuffer := SubStr( cBuffer, nPos + 1 )
      ENDIF

      cLine := Trim( cLine )
      IF Empty( cLine )
         LOOP
      ENDIF

      IF Left( cLine, 6 ) == "data: "
         cJson := SubStr( cLine, 7 )

         IF AllTrim( cJson ) == "[DONE]"
            hState[ "done"   ] := .T.
            hState[ "buffer" ] := ""
            RETURN
         ENDIF

         hb_jsonDecode( cJson, @hJson )
         IF ValType( hJson ) == "H"
            IF "choices" $ hJson .AND. Len( hJson[ "choices" ] ) > 0
               IF "delta" $ hJson[ "choices" ][ 1 ]
                  IF "content" $ hJson[ "choices" ][ 1 ][ "delta" ]
                     cContent := hJson[ "choices" ][ 1 ][ "delta" ][ "content" ]
                     IF ValType( cContent ) == "C" .AND. ! Empty( cContent )
                        ?? cContent
                        hState[ "response" ] += cContent
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDDO

   hState[ "buffer" ] := cBuffer

   RETURN

// ============================================================
// Display Non-Streaming Response
// ============================================================
STATIC PROCEDURE displayResponse( cResponse )

   LOCAL hJson
   LOCAL cContent

   IF Empty( cResponse )
      ? "Error: Empty response from API"
      RETURN
   ENDIF

   hb_jsonDecode( cResponse, @hJson )
   IF ValType( hJson ) == "H"

      IF "error" $ hJson
         ? "API Error: " + hb_valToExp( hJson[ "error" ] )
         RETURN
      ENDIF

      IF "choices" $ hJson .AND. Len( hJson[ "choices" ] ) > 0
         IF "message" $ hJson[ "choices" ][ 1 ]
            IF "content" $ hJson[ "choices" ][ 1 ][ "message" ]
               cContent := hJson[ "choices" ][ 1 ][ "message" ][ "content" ]
               IF ValType( cContent ) == "C"
                  ? "Response:"
                  ? "----------"
                  ? cContent
                  RETURN
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   ? "Raw response:"
   ? cResponse

   RETURN

// ============================================================
// Handle Chat Commands
// ============================================================
STATIC FUNCTION handleCommand( cInput, hOpts, aHistory )

   LOCAL cCmd := Lower( AllTrim( SubStr( cInput, 2 ) ) )
   LOCAL cArg
   LOCAL hMsg
   LOCAL hMsg2

   IF cCmd == "exit" .OR. cCmd == "quit" .OR. cCmd == "q"
      RETURN .F.
   ENDIF

   IF cCmd == "help"
      ? ""
      ? "Commands:"
      ? "  /help              Show this help"
      ? "  /exit, /quit, /q   Exit chat"
      ? "  /clear             Clear conversation history"
      ? "  /model <name>      Change model (current: " + hOpts[ "model" ] + ")"
      ? "  /temp <value>      Change temperature (current: " + hb_ntos( hOpts[ "temp" ] ) + ")"
      ? "  /system <text>     Set system prompt"
      ? "  /history           Show conversation history"
      ? "  /models            List available models"
      ? ""
      RETURN .T.
   ENDIF

   IF cCmd == "clear"
      ASize( aHistory, 0 )
      IF ! Empty( hOpts[ "system" ] )
         addMessage( aHistory, "system", hOpts[ "system" ] )
      ENDIF
      ? "History cleared."
      RETURN .T.
   ENDIF

   IF cCmd == "models"
      showModels()
      RETURN .T.
   ENDIF

   IF Left( cCmd, 6 ) == "model "
      cArg := AllTrim( SubStr( cCmd, 7 ) )
      IF ! Empty( cArg )
         hOpts[ "model" ] := cArg
         ? "Model changed to: " + cArg
      ELSE
         ? "Current model: " + hOpts[ "model" ]
      ENDIF
      RETURN .T.
   ENDIF

   IF Left( cCmd, 5 ) == "temp "
      cArg := AllTrim( SubStr( cCmd, 6 ) )
      IF ! Empty( cArg )
         hOpts[ "temp" ] := Val( cArg )
         ? "Temperature set to: " + hb_ntos( hOpts[ "temp" ] )
      ELSE
         ? "Current temperature: " + hb_ntos( hOpts[ "temp" ] )
      ENDIF
      RETURN .T.
   ENDIF

   IF Left( cCmd, 7 ) == "system "
      cArg := AllTrim( SubStr( cCmd, 8 ) )
      IF ! Empty( cArg )
         hOpts[ "system" ] := cArg
         ? "System prompt updated."
      ELSE
         ? "Current system: " + IIF( Empty( hOpts[ "system" ] ), "(none)", hOpts[ "system" ] )
      ENDIF
      RETURN .T.
   ENDIF

   IF cCmd == "history"
      ? ""
      IF Len( aHistory ) == 0
         ? "No messages in history."
      ELSE
         ? "History (" + hb_ntos( Len( aHistory ) ) + " messages):"
         FOR EACH hMsg2 IN aHistory
            ? "  [" + Upper( hMsg2[ "role" ] ) + "] " + ;
              Left( hMsg2[ "content" ], 80 ) + ;
              IIF( Len( hMsg2[ "content" ] ) > 80, "...", "" )
         NEXT
      ENDIF
      ? ""
      RETURN .T.
   ENDIF

   ? "Unknown command: " + cInput + ". Type /help for commands."
   RETURN .T.

// ============================================================
// Show Help
// ============================================================
STATIC PROCEDURE showHelp()

   ? "OpenCode Zen - Harbour AI Client"
   ? "================================"
   ? ""
   ? "Usage:"
   ? "  veai.exe [options] [prompt]"
   ? ""
   ? "Options:"
   ? "  -h, --help              Show this help"
   ? "  -l, --list              List available models"
   ? "  -c, --chat              Interactive chat mode"
   ? "  -s, --stream            Enable streaming output"
   ? "  -m, --model <name>      Set model (default: " + DEFAULT_MODEL + ")"
   ? "  --system <text>         Set system prompt"
   ? "  --temp <value>          Set temperature (default: " + hb_ntos( DEFAULT_TEMP ) + ")"
   ? ""
   ? "Examples:"
   ? '  veai.exe "What is Harbour?"'
   ? '  veai.exe --chat'
   ? '  veai.exe --chat --system "You are a Harbour expert"'
   ? '  veai.exe --stream --model deepseek-v4-flash-free "Explain OOP"'
   ? '  veai.exe --temp 0.3 "Write a haiku about coding"'
   ? ""

   RETURN

// ============================================================
// Show Available Models
// ============================================================
STATIC PROCEDURE showModels()

   ? "Free models on OpenCode Zen:"
   ? ""
   ? "  Model                        Context"
   ? "  ---------------------------  -------"
   ? "  mimo-v2.5-free               200K"
   ? "  mimo-v2-pro-free             1M"
   ? "  mimo-v2-flash-free           262K"
   ? "  deepseek-v4-flash-free       200K"
   ? "  glm-4.7-free                 204K"
   ? "  glm-5-free                   204K"
   ? "  nemotron-3-ultra-free        1M"
   ? "  minimax-m3-free              200K"
   ? "  kimi-k2.5-free               262K"
   ? "  qwen3.6-plus-free            262K"
   ? "  grok-code                    256K"
   ? ""
   ? 'Use: veai.exe --model <name> "your prompt"'
   ? ""

   RETURN
