// SPIKE HARNESS — #66. Not product code.
//
// The TypeScript twin of Extract.from_html, but walking the LIVE DOM rather than an HTML string.
// Walking the DOM is what makes capture possible at all: the per-character provenance recorded
// here IS the Range -> text-offset map, so no second mapping pass is needed.
//
// Emits, for each extracted character i:
//   text[i]      the character
//   srcMap[i]    source byte offset (Ruby parity — from data-src on the owning text node)
//   nodeMap[i]   [textNodeId, offsetWithinThatNode] or null for synthesised block newlines
//
// Mirrors extract.rb's rules deliberately, including its quirks, so any disagreement is a real
// finding rather than an artefact of two people writing two different extractors.

(function () {
  const INVISIBLE = new Set(["SCRIPT", "STYLE", "HEAD", "TITLE", "META", "LINK"]);
  const BLOCK = new Set([
    "P", "DIV", "H1", "H2", "H3", "H4", "H5", "H6", "LI", "TR", "BR", "HR",
    "SECTION", "ARTICLE", "HEADER", "FOOTER", "PRE", "BLOCKQUOTE",
    "TABLE", "THEAD", "TBODY", "TD", "TH", "UL", "OL",
  ]);

  function extractDom(root) {
    const text = [];
    const nodeMap = [];
    let preDepth = 0;

    // Text nodes get a stable id so a Range endpoint can be looked up without object identity
    // surviving a round trip through JSON.
    const nodes = [];
    const idOf = new Map();

    function blockBreak() {
      const last = text[text.length - 1];
      if (text.length === 0 || last === "\n") return;
      text.push("\n");
      nodeMap.push(null); // synthesised: corresponds to a tag, not to a selectable character
    }

    function walk(node) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        const tag = node.tagName;
        if (INVISIBLE.has(tag)) return;

        const isPre = tag === "PRE";
        const isBlock = isPre || BLOCK.has(tag);
        if (isPre) preDepth++;
        if (isBlock) blockBreak();

        for (const child of node.childNodes) walk(child);

        if (isPre) preDepth--;
        // extract.rb scans tags linearly, so a CLOSING block tag emits a break too. Without this
        // the inter-tag whitespace after </h1> arrives before any newline and survives as a
        // space, desyncing every offset thereafter.
        if (isBlock) blockBreak();
        return;
      }

      if (node.nodeType !== Node.TEXT_NODE) return;

      let id = idOf.get(node);
      if (id === undefined) {
        id = nodes.length;
        nodes.push(node);
        idOf.set(node, id);
      }

      const data = node.data;
      for (let i = 0; i < data.length; i++) {
        const ch = data[i];
        if (/\s/.test(ch)) {
          if (preDepth > 0) {
            text.push(ch);
            nodeMap.push([id, i]);
          } else {
            const last = text[text.length - 1];
            if (text.length > 0 && last !== " " && last !== "\n") {
              text.push(" ");
              nodeMap.push([id, i]);
            }
          }
          continue;
        }
        text.push(ch);
        nodeMap.push([id, i]);
      }
    }

    walk(root);

    // Trim leading/trailing whitespace in lockstep, exactly as extract.rb does.
    let lead = 0;
    while (lead < text.length && /\s/.test(text[lead])) lead++;
    let end = text.length;
    while (end > lead && /\s/.test(text[end - 1])) end--;

    return {
      text: text.slice(lead, end).join(""),
      nodeMap: nodeMap.slice(lead, end),
      nodes,
    };
  }

  // --- Range -> extracted-text offset ---------------------------------------------------------
  //
  // Given a DOM position (textNode, offset), find the extracted-text index it produced. The
  // ambiguity this must resolve: a DOM position inside a COLLAPSED whitespace run produced no
  // character of its own. The rule adopted here is "first extracted character at or after this
  // DOM position" for a start endpoint, and "last extracted character at or before" for an end
  // endpoint -- i.e. both endpoints move INWARD onto real content.

  function positionToOffset(ex, nodeId, nodeOffset, direction) {
    // direction: "start" scans forward, "end" scans backward.
    let best = null;
    for (let i = 0; i < ex.nodeMap.length; i++) {
      const m = ex.nodeMap[i];
      if (m === null) continue;
      const [id, off] = m;
      if (id !== nodeId) continue;
      if (direction === "start") {
        if (off >= nodeOffset) return i;
      } else if (off < nodeOffset) {
        best = i;
      }
    }
    if (direction === "end" && best !== null) return best + 1;

    // The DOM position is past every extracted character of this node (start), or before all of
    // them (end). Fall back to node order: find the first extracted char of a LATER node.
    if (direction === "start") {
      for (let i = 0; i < ex.nodeMap.length; i++) {
        const m = ex.nodeMap[i];
        if (m !== null && m[0] > nodeId) return i;
      }
      return ex.text.length;
    }
    for (let i = ex.nodeMap.length - 1; i >= 0; i--) {
      const m = ex.nodeMap[i];
      if (m !== null && m[0] < nodeId) return i + 1;
    }
    return 0;
  }

  function rangeToOffsets(ex, range) {
    const resolveEndpoint = (container, offset, direction) => {
      if (container.nodeType === Node.TEXT_NODE) {
        const id = ex.nodes.indexOf(container);
        if (id === -1) return null;
        return positionToOffset(ex, id, offset, direction);
      }
      // Element container: the offset indexes childNodes. Descend to the nearest text node.
      const child = container.childNodes[offset] || container.childNodes[container.childNodes.length - 1];
      if (!child) return null;
      const walker = document.createTreeWalker(child, NodeFilter.SHOW_TEXT);
      const t = walker.nextNode();
      if (!t) return null;
      const id = ex.nodes.indexOf(t);
      if (id === -1) return null;
      return positionToOffset(ex, id, direction === "start" ? 0 : t.data.length, direction);
    };

    const start = resolveEndpoint(range.startContainer, range.startOffset, "start");
    const end = resolveEndpoint(range.endContainer, range.endOffset, "end");
    if (start === null || end === null) return null;
    return { start: Math.min(start, end), end: Math.max(start, end) };
  }

  window.__anchorHarness = { extractDom, rangeToOffsets, positionToOffset };
})();
