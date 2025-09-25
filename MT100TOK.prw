#Include "Totvs.ch"

/*/{Protheus.doc} MT100TOK
Ponto de Entrada para valida��o do documento de entrada
Bloqueia lan�amento se o vencimento for menor que o prazo calculado
@type function
@version 12.1.33
@author Luiz Felipe Falc�o Fran�a
@since 25/09/2025
@return logical, permite ou n�o o lan�amento
/*/
User Function MT100TOK()
Local lRet      := .T.
Local dDtDigit  := M->F1_DTDIGIT     // Data de Digita��o da NF
Local nPosVenc  := aScan(aHeader,{|x| AllTrim(x[2]) == "E2_VENCTO"})  // Posi��o do Vencimento
Local dVencto   := CtoD("")
Local nDias     := 0
Local cCond     := M->F1_CONDPAG     // Condi��o de Pagamento da NF (CORRIGIDO)
Local nX        := 0

    // Se n�o achou campo de vencimento, retorna
    If nPosVenc == 0
        Return .T.
    EndIf

    // Posiciona na Condi��o de Pagamento
    DbSelectArea("SE4")
    SE4->(DbSetOrder(1))
    If SE4->(DbSeek(xFilial("SE4") + cCond))
        // Pega o prazo da condi��o
        nDias := SE4->E4_DIAS
        
        // Percorre as parcelas (t�tulos)
        For nX := 1 To Len(aCols)
            // Se linha n�o deletada
            If !aCols[nX][Len(aHeader)+1]
                dVencto := aCols[nX][nPosVenc]  // Data de vencimento informada
                
                // Data m�nima permitida: Data Digita��o + Dias da condi��o
                If !Empty(dVencto) .And. dVencto < DaySum(dDtDigit, nDias)
                    lRet := .F.
                    MsgStop("Data de vencimento inferior ao prazo m�nimo!" + CRLF + ;
                           "Parcela: " + cValToChar(nX) + CRLF + ;
                           "Data Entrada NF: " + DtoC(dDtDigit) + CRLF + ;
                           "Prazo: " + cValToChar(nDias) + " dias" + CRLF + ;
                           "Vencimento M�nimo: " + DtoC(DaySum(dDtDigit, nDias)) + CRLF + ;
                           "Vencimento Informado: " + DtoC(dVencto),;
                           "Vencimento Inv�lido")
                    Exit
                EndIf
            EndIf
        Next nX
    EndIf

Return lRet
