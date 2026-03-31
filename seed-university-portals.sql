-- ============================================================
-- SEED: University Portal Mapping for VitaAI
-- Generated: 2026-03-29
-- Source: HTTP probes on 351 Brazilian medical schools
-- ============================================================

-- First, add capabilities column if not exists
-- ALTER TABLE vita.universities ADD COLUMN IF NOT EXISTS capabilities jsonb;
-- ALTER TABLE vita.universities ADD COLUMN IF NOT EXISTS connectorStrategy text;
-- ALTER TABLE vita.universities ADD COLUMN IF NOT EXISTS displayName text;
-- ALTER TABLE vita.universities ADD COLUMN IF NOT EXISTS isPrimary boolean DEFAULT true;

BEGIN;

-- ============================================================
-- CANVAS instances (native_api) — ~80 universities via ~12 tenants
-- ============================================================

-- Afya group → afya.instructure.com
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'afya.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN (
  'enamed-167-afya-guanambi', 'enamed-249-afya-itabuna', 'enamed-253-afya-fcm-vic',
  'enamed-252-afya-santa-in-s', 'enamed-50-afya-montes-claros', 'enamed-165-afya-sj-del-rei',
  'enamed-51-afya-ipatinga', 'enamed-169-afya-itajub', 'enamed-335-faseh',
  'enamed-251-afya-marab', 'enamed-170-afya-reden--o', 'enamed-248-afya-para-ba',
  'enamed-250-afya-jaboat-o', 'enamed-166-afya-teresina', 'enamed-244-afya-parna-ba',
  'enamed-246-afya-itaperuna', 'enamed-256-unigranrio', 'enamed-255-unigranrio',
  'enamed-247-afya-porto-velho', 'enamed-168-afya-palmas', 'enamed-245-afya-aragua-na',
  'enamed-254-afya-porto-nacional', 'enamed-60-unifg', 'enamed-276-faculdade-ages',
  'enamed-277-faculdade-ages'
);

-- Kroton/Cogna → kroton.instructure.com
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'kroton.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN (
  'enamed-299-uniderp', 'enamed-306-unic-unime', 'enamed-300-uam', 'enamed-301-uam', 'enamed-302-uam',
  'enamed-273-unime', 'enamed-293-eun-polis'
);

-- Estácio/Yduqs → estacio.instructure.com
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'estacio.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN (
  'enamed-220-unesa', 'enamed-348-unesa', 'enamed-221-unesa',
  'enamed-199-est-cio-fmj', 'enamed-290-est-cio-canind', 'enamed-291-est-ciojuazeiro',
  'enamed-263-est-cio-ribeir-o-pre', 'enamed-289-alagoinhas', 'enamed-336-est-cio-jaragu',
  'enamed-332-unipantanal'
);

-- Ser Educacional → sereducacional.instructure.com
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'sereducacional.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN (
  'enamed-269-uninassau', 'enamed-268-uninassau', 'enamed-189-uninassau',
  'enamed-160-unp', 'enamed-297-vilhena'
);

-- Anima Educação → animaeducacao.instructure.com
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'animaeducacao.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN (
  'enamed-175-uni-bh', 'enamed-218-unisul', 'enamed-217-unisul', 'enamed-242-usjt'
);

-- ULBRA → ulbra.instructure.com
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'ulbra.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN (
  'enamed-321-ulbra', 'ulbra-poa'
);

-- Individual Canvas instances
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'pucminas.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN ('enamed-77-puc-minas', 'enamed-202-puc-minas', 'enamed-203-puc-minas');
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'pucpr.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN ('enamed-79-pucpr', 'enamed-204-pucpr');
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unifor.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-85-unifor';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unichristus.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-1-unichristus';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'uvv.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-163-uvv';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'ucs.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-84-ucs';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'univali.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-100-univali';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'positivo.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-49-up';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'usp.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN ('enamed-19-usp', 'enamed-20-usp', 'enamed-18-usp');
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'ufscar.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-39-ufscar';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'usf.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-241-usf';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unimar.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-309-unimar';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unit.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-243-unit';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'mackenzie.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-71-fempar';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'afya.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-74-unir';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'cesmac.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-173-cesmac';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'niltonlins.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-350-uniniltonlins';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'puc-rio.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-78-pucsp'; -- PUC-Rio not in this list, PUCSP Sorocaba uses moodle
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'ucb.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-80-ucb';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'uninta.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-186-uninta';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unesc.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-58-unesc';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'univates.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-314-univates';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'feevale.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-228-feevale';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unijui.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-239-unijui';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'uri.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-161-uri';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unesc.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-95-unesc';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unoesc.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-96-unoesc';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'uit.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-308-ui';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'uniube.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-90-uniube';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'fame.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-283-fame';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'cam.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-329-cam';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'facisb.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-4-facisb';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'einstein.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-9-ficsae';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'puc-campinas.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-76-puc-campinas';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'umc.instructure.com', "portalAuthMethod" = 'oauth' WHERE id = 'enamed-344-umc';
UPDATE vita.universities SET "portalType" = 'canvas', "portalUrl" = 'unicesumar.instructure.com', "portalAuthMethod" = 'oauth' WHERE id IN ('enamed-81-unicesumar', 'enamed-296-corumb');

-- ============================================================
-- SIGAA (vita_crawl) — ~30 federal/state universities
-- ============================================================

UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.sig.ufal.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-116-ufal', 'enamed-117-ufal');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.unb.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-83-unb';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.sistemas.ufg.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-122-ufg';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.sistemas.ufj.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-123-ufj';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufma.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-143-ufma', 'enamed-144-ufma', 'enamed-317-ufma');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufla.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-124-ufla';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufsj.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-134-ufsj', 'enamed-135-ufsj');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufpa.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-226-ufpa', 'enamed-349-ufpa');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.uepa.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-92-uepa', 'enamed-22-uepa', 'enamed-215-uepa');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufpb.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-115-ufpb';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufcg.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-120-ufcg', 'enamed-119-ufcg');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufpe.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-128-ufpe', 'enamed-129-ufpe');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.upe.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-88-upe', 'enamed-16-upe', 'enamed-17-upe');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sig.univasf.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-13-univasf', 'enamed-14-univasf');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufpi.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-148-ufpi', 'enamed-149-ufpi');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.uespi.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-110-uespi';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufrn.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-47-ufrn', 'enamed-48-ufrn');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.uern.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-94-uern';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufrr.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-131-ufrr';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufs.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-40-ufs', 'enamed-41-ufs');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.unifap.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-138-unifap';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufba.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-113-ufba', 'enamed-32-ufba');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufrb.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-227-ufrb';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sig.ufsb.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-318-ufsb';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'si3.ufc.br/sigaa', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-44-ufc', 'enamed-140-ufc');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sig.ufca.edu.br/sigaa', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-139-ufca';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.uffs.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-114-uffs', 'enamed-223-uffs');
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sig.ufob.edu.br/sigaa', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-146-ufob';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufersa.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-158-ufersa';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sistemas.ufcat.edu.br/sigaa', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-121-ufcat';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sis.sig.uema.br/sigaa', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-107-uema';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.uemasul.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-222-uemasul';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufdpar.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-141-ufdpar';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.unila.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-316-unila';
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufrj.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-150-ufrj', 'enamed-151-ufrj');

-- ============================================================
-- MOODLE (native_api via token) — ~35 universities
-- ============================================================

UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufrgs.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-153-ufrgs';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufcspa.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-12-ufcspa';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.pucrs.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-15-pucrs';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufsc.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-132-ufsc', 'enamed-224-ufsc');
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-42-ufu';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufjf.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-34-ufjf', 'enamed-33-ufjf');
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufop.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-38-ufop';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.pucsp.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-78-pucsp';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.famema.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-7-famema';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unirg.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-307-unirg';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.uefs.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-103-uefs';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.ufms.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-36-ufms', 'enamed-35-ufms');
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unesp.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-31-unesp';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.ufabc.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-136-unifesp'; -- UNIFESP uses custom, keeping for now
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unifenas.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-237-unifenas', 'enamed-236-unifenas');
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'e-aula.ufpel.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-127-ufpel';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.uncisal.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-102-uncisal';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.unieuro.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-184-unieuro';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.undf.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-21-undf';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.uerr.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-315-uerr';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unipampa.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-200-unipampa';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'portalvirtual.unisc.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-210-unisc';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.furg.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-152-furg';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.ufn.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-229-ufn';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.furb.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-238-furb';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unifan.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-327-unifan';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.unifimes.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-260-unifimes', 'enamed-259-unifimes');
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unirv.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-312-fesurv', 'enamed-311-fesurv', 'enamed-345-fesurv', 'enamed-346-fesurv');
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unicentro.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-29-unicentro';
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'moodle.unioeste.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-108-unioeste', 'enamed-109-unioeste');

-- ============================================================
-- TOTVS RM (vita_crawl) — ~25 universities
-- ============================================================

UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.cesupa.br/Corpore.Net', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-59-cesupa';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portaldoaluno.grupoceuma.com.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-303-uniceuma', 'enamed-304-uniceuma');
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'rm.cloudtotvs.com.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-68-fcmmg';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.unifacs.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-240-unifacs';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'www3.unaerp.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-89-unaerp', 'enamed-310-unaerp');
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.uniceplac.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-183-uniceplac';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.fimca.com.br/FrameHTML', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-257-fimca';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portaleducacional.atitus.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-280-atitus-educa--o';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'ucpel.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-206-ucpel';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.asav.org.br/EducaMobile', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-219-unisinos';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portalrm.uniarp.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-205-uniarp';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'www2.baraodemaua.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-53-cbm';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'unifaj.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-177-unifaj';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'centralaluno.unifunec.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-261-unifunec';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portaluniversitario.saocamilo.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-65-sao-camilo';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'anbarensino158272.rm.cloudtotvs.com.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-195-faceres';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.ub.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-343-ub';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.uniatenas.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-171-uniatenas';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.faminas.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-266-unifaminas';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portal.unipac.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-333-unipac';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'portalaluno.unifagoc.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-62-unifagoc';
UPDATE vita.universities SET "portalType" = 'totvs', "portalUrl" = 'soegarsociedade156443.rm.cloudtotvs.com.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-274-univ-rtix';

-- ============================================================
-- SAGRES (vita_crawl) — 5 universities
-- ============================================================

UPDATE vita.universities SET "portalType" = 'sagres', "portalUrl" = 'prograd.uesc.br/PortalSagres', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-27-uesc';
UPDATE vita.universities SET "portalType" = 'sagres', "portalUrl" = 'sagres.uesb.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-30-uesb', 'enamed-111-uesb');
UPDATE vita.universities SET "portalType" = 'sagres', "portalUrl" = 'portalacademico.uneb.br/PortalSagres', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-91-uneb';

-- ============================================================
-- LYCEUM / CLARIENS (vita_crawl) — ~8 universities
-- ============================================================

UPDATE vita.universities SET "portalType" = 'lyceum', "portalUrl" = 'portal.unievangelica.edu.br/aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-112-unievang-lica';
UPDATE vita.universities SET "portalType" = 'lyceum', "portalUrl" = 'academicoaluno.fps.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-72-fps';
UPDATE vita.universities SET "portalType" = 'lyceum', "portalUrl" = 'portal.clariens.com.br/aluno', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-275-zarns-salvador', 'enamed-298-unesulbahia', 'enamed-340-itumbiara', 'enamed-63-araguari');
UPDATE vita.universities SET "portalType" = 'lyceum', "portalUrl" = 'facig.lyceum.com.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-272-manhua-u';

-- ============================================================
-- PHIDELIS (vita_crawl) — 1 university
-- ============================================================

UPDATE vita.universities SET "portalType" = 'phidelis', "portalUrl" = 'aluno.emescam.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-67-emescam';

-- ============================================================
-- CUSTOM / PRÓPRIO (vita_crawl) — remaining
-- ============================================================

-- USP (JupiterWeb)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'uspdigital.usp.br/jupiterweb', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-19-usp', 'enamed-20-usp', 'enamed-18-usp');
-- Note: USP already set to Canvas above — USP uses BOTH. Canvas is primary for LMS.

-- UFMG (minhaUFMG)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'minha.ufmg.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-37-ufmg';

-- UNICAMP (DAC)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'dac.unicamp.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-23-unicamp';

-- UERJ (Aluno Online)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'alunoonline.uerj.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-93-uerj';

-- UNIRIO (SIE)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portais.unirio.br/aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-142-unirio';

-- UFF (IdUFF)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'app.uff.br/iduff', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-157-uff';

-- UFPR (SIGA)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'prppg.ufpr.br/siga', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-147-ufpr', 'enamed-46-ufpr');

-- UFSM (Portal Estudantil)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portal.ufsm.br/aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-133-ufsm';

-- UFPel (Cobalto)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'cobalto.ufpel.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-127-ufpel';

-- UECE (SisAcadG)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sisacadg.uece.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-28-uece';

-- UFAC
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sistemas.ufac.br/portal-aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-137-ufac';

-- UFAM (e-Campus)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'ecampus.ufam.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-225-ufam';

-- UEA (SIGED)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'siged.amazonas.am.gov.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-214-uea';

-- UFMT (SIGA)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'siga.ufmt.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-125-ufmt', 'enamed-126-ufmt');

-- UFES
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'academico.ufes.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-45-ufes';

-- UFVJM (e-Campus)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'ecampus.ufvjm.edu.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-156-ufvjm', 'enamed-155-ufvjm');

-- UFTM
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sistemas.uftm.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-154-uftm';

-- UFT
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sistemas.uft.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-75-uft';

-- UFNT
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portal.ufnt.edu.br/aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-145-ufnt';

-- UFR (Rondonópolis)
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.ufr.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-130-ufr';

-- UNEMAT
UPDATE vita.universities SET "portalType" = 'sigaa', "portalUrl" = 'sigaa.unemat.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-212-unemat';

-- UNINOVE (Central do Aluno)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'aluno.uninove.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-232-uninove', 'enamed-233-uninove', 'enamed-234-uninove', 'enamed-235-uninove', 'enamed-322-uninove', 'enamed-323-uninove');

-- UNISA (Oracle)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'w3.unisa.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-325-unisa';

-- USCS (SmaraPD)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'uscs.smarapd.com.br', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-159-uscs', 'enamed-231-uscs');

-- UNIT Estância (Magister)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'magister.grupotiradentes.com', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-162-unit';

-- UNNESA (SGA CIEBE)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sga.ciebe.com.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-337-unnesa';

-- EBMSP (Moodle AVA)
UPDATE vita.universities SET "portalType" = 'moodle', "portalUrl" = 'ava.bahiana.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-66-ebmsp';

-- UNIFACID WYDEN (Blackboard)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'unifacid.blackboard.com', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-185-unifacid-wyden';

-- São Leopoldo Mandic (Microsoft 365)
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'slmandicedu.sharepoint.com', "portalAuthMethod" = 'microsoft_sso' WHERE id IN ('enamed-295-campinas', 'enamed-339-slmandic-araras');

-- CEUNI-FAMETRO
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portal.ceunifametro.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-328-ceuni-fametro';

-- UEG
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'app.ueg.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-104-ueg';

-- UNIPAM
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portal.unipam.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-56-unipam';

-- UEL
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sistemas.uel.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-105-uel';

-- UEM
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'daa.uem.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-24-uem';

-- UEPG
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sistemas.uepg.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-26-uepg';

-- FAMERP
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'intranetalunos.famerp.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-8-famerp';

-- FMJ
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'academico.fmj.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-6-fmj';

-- FCMSCSP
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portal.fcmsantacasasp.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-5-fcmscsp';

-- FMABC
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'fmabc.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-61-fmabc';

-- UNITAU
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'unitau.br/aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-313-unitau';

-- UNOESTE
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'unoeste.br/site/ava', "portalAuthMethod" = 'credentials' WHERE id IN ('enamed-97-unoeste', 'enamed-98-unoeste', 'enamed-216-unoeste');

-- FAMENE
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'famene.com.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-286-famene';

-- UNIVILLE
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'univille.edu.br/portal-do-aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-208-univille';

-- UNIMONTES
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'portal.unimontes.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-25-unimontes';

-- PUC Goiás
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'sistema.pucgoias.edu.br', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-201-puc-goi-s';

-- UNILUS
UPDATE vita.universities SET "portalType" = 'custom', "portalUrl" = 'unilus.edu.br/login/aluno', "portalAuthMethod" = 'credentials' WHERE id = 'enamed-188-unilus';

COMMIT;

-- ============================================================
-- VERIFY: Count populated vs empty
-- ============================================================
-- SELECT
--   COUNT(*) as total,
--   COUNT("portalType") as mapped,
--   COUNT(*) - COUNT("portalType") as unmapped
-- FROM vita.universities;
