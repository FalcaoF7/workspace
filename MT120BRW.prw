#Include "Protheus.ch"
#Include "FWMVCDef.ch"

/*/{Protheus.doc} MT120BRW 
    Ponto de entrada para adicionar op��es no menu do MATA120 (Pedido de Compra)
/*/
User Function MT120BRW()
    AAdd(aRotina, {"Alt. Dt Entrega", "U_ALTDTENT()", 0, 4, 0, NIL})
Return aRotina

/*/{Protheus.doc} ALTDTENT
    Fun��o para alterar data de entrega sem voltar para aprova��o
/*/
User Function ALTDTENT()
    Local aArea     := GetArea()
    Local aAreaSC7  := SC7->(GetArea())
    Local nOpca     := 0
    Local dNovaData := SC7->C7_DATPRF + 1  // Inicializa com data atual + 1 dia
    Local cObserv   := Space(200)
    Local cPedido   := ""
    Local cFornecedor := ""
    Local cDataAtual := ""
    Local oDlg, oGet1, oGet2, oGet3, oGet4, oMemo
    Local oBtnSalvar, oBtnCancelar
    
    // Verifica se h� pedido posicionado
    If SC7->(Eof()) .Or. Empty(SC7->C7_NUM)
        MsgAlert("Nenhum pedido selecionado!", "Aten��o")
        RestArea(aAreaSC7)
        RestArea(aArea)
        Return
    EndIf
    
    // Verifica se o pedido j� foi liberado/aprovado
    If SC7->C7_CONAPRO <> "L"
        MsgAlert("Pedido ainda n�o foi liberado/aprovado!" + CRLF + "Status: " + SC7->C7_CONAPRO, "Aten��o")
        RestArea(aAreaSC7)
        RestArea(aArea)
        Return
    EndIf
    
    // Carrega dados para exibi��o
    cPedido     := SC7->C7_NUM
    cFornecedor := AllTrim(SC7->C7_FORNECE) + " - " + AllTrim(Posicione("SA2",1,xFilial("SA2")+SC7->C7_FORNECE+SC7->C7_LOJA,"A2_NOME"))
    cDataAtual  := DToC(SC7->C7_DATPRF)
    
    // Define a tela (aumentando altura para caber os bot�es)
    DEFINE MSDIALOG oDlg TITLE "Altera��o de Data de Entrega" FROM 000,000 TO 320,500 PIXEL
    
        // Pedido
        @ 020,020 SAY "Pedido:" SIZE 060,010 OF oDlg PIXEL
        @ 020,080 MSGET oGet1 VAR cPedido SIZE 080,012 OF oDlg PIXEL WHEN .F.
        
        // Fornecedor  
        @ 040,020 SAY "Fornecedor:" SIZE 060,010 OF oDlg PIXEL
        @ 040,080 MSGET oGet2 VAR cFornecedor SIZE 160,012 OF oDlg PIXEL WHEN .F.
        
        // Data Atual
        @ 060,020 SAY "Data Atual:" SIZE 060,010 OF oDlg PIXEL
        @ 060,080 MSGET oGet3 VAR cDataAtual SIZE 080,012 OF oDlg PIXEL WHEN .F.
        
        // Nova Data (removendo picture que pode causar problema)
        @ 080,020 SAY "Nova Data:" SIZE 060,010 OF oDlg PIXEL
        @ 080,080 MSGET oGet4 VAR dNovaData SIZE 080,012 OF oDlg PIXEL
        
        // Observa��o
        @ 100,020 SAY "Observa��o:" SIZE 060,010 OF oDlg PIXEL
        @ 115,020 GET oMemo VAR cObserv MEMO SIZE 220,050 OF oDlg PIXEL
        
        // Bot�es (posicionamento corrigido)
        @ 180,160 BUTTON oBtnSalvar PROMPT "Salvar" SIZE 050,015 OF oDlg PIXEL ACTION (ProcessaSalvar(@nOpca, dNovaData, cObserv, @oDlg))
        @ 180,220 BUTTON oBtnCancelar PROMPT "Cancelar" SIZE 050,015 OF oDlg PIXEL ACTION (nOpca := 0, oDlg:End())
        
    ACTIVATE MSDIALOG oDlg CENTERED
    
    // Se confirmou, processa a altera��o
    If nOpca == 1
        Processa({|| ProcAltData(dNovaData, cObserv)}, "Processando", "Alterando data de entrega...")
    EndIf
    
    RestArea(aAreaSC7)
    RestArea(aArea)
    
Return

/*/{Protheus.doc} ProcessaSalvar
    Processa o clique no bot�o Salvar
/*/
Static Function ProcessaSalvar(nOpca, dNovaData, cObserv, oDlg)
    
    If ValidaData(dNovaData, cObserv)
        nOpca := 1
        oDlg:End()
    EndIf
    
Return

/*/{Protheus.doc} ValidaData
    Valida a nova data informada
/*/
Static Function ValidaData(dData, cObs)
    Local lRet := .T.
    
    // Valida se a data foi informada
    If Empty(dData)
        MsgAlert("Informe a nova data de entrega!", "Aten��o")
        lRet := .F.
    
    // Valida se a data n�o � menor que hoje    
    ElseIf dData < Date()
        MsgAlert("A nova data n�o pode ser menor que a data atual!", "Aten��o")
        lRet := .F.
        
    // Valida se a data � diferente da atual
    ElseIf dData == SC7->C7_DATPRF
        MsgAlert("A nova data deve ser diferente da data atual!", "Aten��o")
        lRet := .F.
    EndIf
    
Return lRet

/*/{Protheus.doc} ProcAltData  
    Processa a altera��o da data de entrega
/*/
Static Function ProcAltData(dNovaData, cObserv)
    Local aArea     := GetArea()
    Local aAreaSC7  := SC7->(GetArea())
    Local cNumPC    := SC7->C7_NUM
    Local dDataAnt  := SC7->C7_DATPRF
    Local lRet      := .T.
    Local nItens    := 0
    
    Begin Transaction
    
        // Altera todos os itens do pedido
        SC7->(DbSetOrder(1)) // C7_FILIAL+C7_NUM+C7_ITEM+C7_SEQUEN
        
        If SC7->(DbSeek(xFilial("SC7") + cNumPC))
            
            While SC7->(!Eof()) .And. SC7->C7_FILIAL == xFilial("SC7") .And. SC7->C7_NUM == cNumPC
                
                RecLock("SC7", .F.)
                    SC7->C7_DATPRF := dNovaData
                    
                    // Se existe campo de observa��o customizado, grava
                    If SC7->(FieldPos("C7_OBSALT")) > 0
                        SC7->C7_OBSALT := "Data alterada de " + DtoC(dDataAnt) + " para " + DtoC(dNovaData) + ;
                                        " em " + DtoC(Date()) + " " + Time() + " por " + RetCodUsr() + ;
                                        IIF(!Empty(AllTrim(cObserv)), " - Obs: " + AllTrim(cObserv), "")
                    EndIf
                    
                SC7->(MsUnlock())
                
                nItens++
                SC7->(DbSkip())
            EndDo
            
            // Grava log da altera��o
            ConOut("ALTDTENT - PC: " + cNumPC + " - " + cValToChar(nItens) + " itens alterados")
            ConOut("Data alterada de " + DtoC(dDataAnt) + " para " + DtoC(dNovaData) + " - Usuario: " + RetCodUsr())
            
        Else
            lRet := .F.
            MsgAlert("Erro ao localizar o pedido!", "Erro")
        EndIf
        
    End Transaction
    
    If lRet
        MsgInfo("Data de entrega alterada com sucesso!" + CRLF + ;
                "PC: " + cNumPC + CRLF + ;
                "Itens alterados: " + cValToChar(nItens) + CRLF + ;
                "Data Anterior: " + DtoC(dDataAnt) + CRLF + ;
                "Nova Data: " + DtoC(dNovaData), "Sucesso")
    EndIf
    
    RestArea(aAreaSC7)  
    RestArea(aArea)
    
Return lRet
