#Include "Totvs.ch"

/*/{Protheus.doc} MT100TOK
Ponto de Entrada para validação do documento de entrada
Bloqueia lançamento se o vencimento for menor que o prazo calculado
@type function
@version 12.1.33
@author Luiz Felipe Falcão França
@since 25/09/2025
@return logical, permite ou não o lançamento
/*/
User Function MT100TOK()
Local lRet      := .T.
Local dDtDigit  := M->F1_DTDIGIT     // Data de Digitação da NF
Local nPosVenc  := aScan(aHeader,{|x| AllTrim(x[2]) == "E2_VENCTO"})  // Posição do Vencimento
Local dVencto   := CtoD("")
Local nDias     := 0
Local cCond     := M->F1_CONDPAG     // Condição de Pagamento da NF (CORRIGIDO)
Local nX        := 0

    // Se não achou campo de vencimento, retorna
    If nPosVenc == 0
        Return .T.
    EndIf

    // Posiciona na Condição de Pagamento
    DbSelectArea("SE4")
    SE4->(DbSetOrder(1))
    If SE4->(DbSeek(xFilial("SE4") + cCond))
        // Pega o prazo da condição
        nDias := SE4->E4_DIAS
        
        // Percorre as parcelas (títulos)
        For nX := 1 To Len(aCols)
            // Se linha não deletada
            If !aCols[nX][Len(aHeader)+1]
                dVencto := aCols[nX][nPosVenc]  // Data de vencimento informada
                
                // Data mínima permitida: Data Digitação + Dias da condição
                If !Empty(dVencto) .And. dVencto < DaySum(dDtDigit, nDias)
                    lRet := .F.
                    MsgStop("Data de vencimento inferior ao prazo mínimo!" + CRLF + ;
                           "Parcela: " + cValToChar(nX) + CRLF + ;
                           "Data Entrada NF: " + DtoC(dDtDigit) + CRLF + ;
                           "Prazo: " + cValToChar(nDias) + " dias" + CRLF + ;
                           "Vencimento Mínimo: " + DtoC(DaySum(dDtDigit, nDias)) + CRLF + ;
                           "Vencimento Informado: " + DtoC(dVencto),;
                           "Vencimento Inválido")
                    Exit
                EndIf
            EndIf
        Next nX
    EndIf

Return lRet
