# SimuladoPreviewRequest

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**areaSlugs** | **[String]** | Nível 1: slugs das 6 grandes áreas (vita.exam_great_areas). | [optional] 
**disciplineSlugs** | **[String]** | Nível 2: slugs de disciplina (vita.disciplines.slug). | [optional] 
**institutionIds** | **[Int]** |  | [optional] 
**years** | [**QBankPreviewRequestYears**](QBankPreviewRequestYears.md) |  | [optional] 
**difficulties** | **[String]** |  | [optional] 
**format** | **[String]** |  | [optional] 
**hideAnswered** | **Bool** |  | [optional] 
**hideAnnulled** | **Bool** |  | [optional] 
**excludeNoExplanation** | **Bool** |  | [optional] 
**includeSynthetic** | **Bool** |  | [optional] 
**questionCount** | **Int** | Pra calcular estimatedMinutes (1.5 min/Q se !timed). | [optional] 
**timed** | **Bool** |  | [optional] 
**timeLimitMinutes** | **Int** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


