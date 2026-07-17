# QBankFilters

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**groups** | [QBankFiltersGroupsInner] | Nível 1 da taxonomia canônica: as 6 GRANDES ÁREAS (vita.exam_great_areas), na ordem canônica (display_order). Cada item tem slug + name + count, e &#x60;children[]&#x60; &#x3D; as DISCIPLINAS daquela área (nível 2). O nível 3 (temas) vai em &#x60;topics[]&#x60;. Taxonomia &#x3D; 1 árvore só: ÁREA → DISCIPLINA → TEMA (vita-shell §1.1). As lentes (tradicional/pbl/great-areas) foram aposentadas em 2026-07-16.  | [optional] 
**institutions** | [QBankFiltersInstitutionsInner] |  | [optional] 
**topics** | [QBankFiltersTopicsInner] |  | [optional] 
**disciplines** | [QBankFiltersDisciplinesInner] | [DEPRECATED 2026-04-17b] Catalog view from qbank_topics.disciplineSlug + vita.disciplines. Use GET /api/subjects instead — QBank must filter by the student&#39;s actual enrolled subjects, not the universal MedSimple catalog. This field stays for fallback during iOS/Android migration and may be removed in 2026-05.  | [optional] 
**years** | [QBankFiltersYearsInner] |  | [optional] 
**difficulties** | [QBankFiltersDifficultiesInner] |  | [optional] 
**totalQuestions** | **Int** |  | [optional] 
**totalAllStages** | **Int** |  | [optional] 
**stage** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


