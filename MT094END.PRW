#Include "Totvs.ch"

// Demandas
// 1 - Vincular a data de entrega à partir da data de aprovação do pedido
// 2 - Bloquear o fiscal/financeiro de lançar o pagamento antes do prazo de 
//   pagamento à partir da entrada do item

User Function MT094END()
Local cNumDoc       := ParamIXB[01] // Número do documento
Local cTipoDoc      := ParamIXB[02] // Tipo do documento
Local nOper         := ParamIXB[03] // Operação: 1-Aprovar, 2-Reprovar, 3-Cancelar
Local cFilDoc       := ParamIXB[04] // Filial do documento
Local aArea         := GetArea() // Salva áreas
Local aAreaSC7      := SC7->(GetArea()) // Salva área SC7
Local aAreaSCR      := SCR->(GetArea()) // Salva área SCR
Local nDiasEntr     := 0            // Dias para entrega
Local dDataOriginal := CtoD("")   // Data original

    RpcSetEnv("01", "01")

    If cTipoDoc == "PC" .And. (nOper == 1 .Or. nOper == 3) .And. SCR->CR_STATUS $ "03/05"
        
        // Posiciona no Pedido de Compra
        DbSelectArea("SC7")
        SC7->(DbSetOrder(1))
        SC7->(DbSeek(cFilDoc + cNumDoc))
            
        // Guarda a data original de entrega
        dDataOriginal := SC7->C7_DATPRF
            
        // Calcula a diferença de dias entre emissão e entrega original
        nDiasEntr := DateDiffDay(SC7->C7_EMISSAO, dDataOriginal)
            
        // Posiciona na Aprovação
        DbSelectArea("SCR")
        SCR->(DbSetOrder(1))
        SCR->(DbSeek(xFilial("SCR") + "PC" + cNumDoc))
                
        // Atualiza as datas no pedido
        RecLock("SC7", .F.)
        SC7->C7_DATPRF := DaySum(dDataBase, nDiasEntr) // Nova data: Aprovação + Dias originais
        SC7->C7_DTAPRV := dDataBase                    // Grava data de aprovação
        SC7->(MsUnlock())
      
    EndIf
    RpcClearEnv()

    // Restaura áreas
    RestArea(aAreaSCR)
    RestArea(aAreaSC7)
    RestArea(aArea)
Return Nil
